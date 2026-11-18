import Foundation

/// ATProto session auth for the SECOND delve.town account — the daily clock
/// tower. Identical flow to `DelvetownAuthService` (app-password exchange,
/// access/refresh JWT in Keychain, background refresh with full re-login
/// recovery) but wired to `ClockTowerKeychain`, so it holds the clock-tower
/// account's session completely separate from Octavia's.
@MainActor
final class ClockTowerAuthService: ObservableObject {
    static let shared = ClockTowerAuthService()

    static let createSessionEndpoint  = URL(string: "https://pds.delve.town/xrpc/com.atproto.server.createSession")!
    static let refreshSessionEndpoint = URL(string: "https://pds.delve.town/xrpc/com.atproto.server.refreshSession")!
    static let deleteSessionEndpoint  = URL(string: "https://pds.delve.town/xrpc/com.atproto.server.deleteSession")!

    @Published private(set) var authState: AuthState = .signedOut

    enum AuthState: Equatable {
        case signedOut
        case authorizing
        case signedIn(handle: String)
        case error(String)
    }

    /// In-flight token refresh, if any. Concurrent posts would otherwise each
    /// kick off their own refresh and race; we coalesce them onto one — same
    /// single-flight pattern as `DelvetownAuthService`.
    private var refreshTask: Task<Void, Error>?

    private init() {
        if ClockTowerKeychain.get(.refreshJwt) != nil,
           let handle = ClockTowerKeychain.get(.handle) {
            authState = .signedIn(handle: handle)
        }
    }

    /// Start a sign-in with a handle + app password. No browser redirect —
    /// ATProto app passwords are exchanged directly.
    func signIn(handle: String, appPassword: String) {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !appPassword.isEmpty else {
            authState = .error("Handle and app password are both required.")
            return
        }
        authState = .authorizing
        Task { await performSignIn(handle: trimmed, appPassword: appPassword) }
    }

    private func performSignIn(handle: String, appPassword: String) async {
        do {
            let session = try await createSession(identifier: handle, password: appPassword)
            persist(session)
            ClockTowerKeychain.set(appPassword, for: .appPassword)
            authState = .signedIn(handle: session.handle)
        } catch {
            authState = .error(error.localizedDescription)
        }
    }

    func signOut() {
        // Best-effort server-side session teardown; the keychain clear below
        // is authoritative and can't fail.
        if let refresh = ClockTowerKeychain.get(.refreshJwt) {
            Task { try? await deleteSession(refreshJwt: refresh) }
        }
        ClockTowerKeychain.clearAll()
        authState = .signedOut
    }

    /// Returns a currently-valid access JWT, refreshing if needed.
    func currentAccessJwt() async throws -> String {
        if let expiryStr = ClockTowerKeychain.get(.accessJwtExpiry),
           let expiry = ISO8601DateFormatter().date(from: expiryStr),
           Date() < expiry.addingTimeInterval(-60),
           let token = ClockTowerKeychain.get(.accessJwt) {
            return token
        }
        try await refreshAccessTokenCoalesced()
        guard let token = ClockTowerKeychain.get(.accessJwt) else {
            throw DelvetownError.notAuthenticated
        }
        return token
    }

    private func refreshAccessToken() async throws {
        guard let refresh = ClockTowerKeychain.get(.refreshJwt) else {
            throw DelvetownError.notAuthenticated
        }
        do {
            let session = try await refreshSession(refreshJwt: refresh)
            persist(session)
        } catch {
            // Refresh failed (expired/rotated/revoked) — recover with a full
            // re-login using the stored app password, if we have one.
            if let handle = ClockTowerKeychain.get(.handle),
               let appPassword = ClockTowerKeychain.get(.appPassword) {
                let session = try await createSession(identifier: handle, password: appPassword)
                persist(session)
                return
            }
            throw error
        }
    }

    private func refreshAccessTokenCoalesced() async throws {
        if let existing = refreshTask {
            try await existing.value
            return
        }
        let task = Task { try await self.refreshAccessToken() }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    // MARK: HTTP

    private struct Session {
        let accessJwt: String
        let refreshJwt: String
        let handle: String
        let did: String
    }

    private struct SessionResponse: Decodable {
        let accessJwt: String
        let refreshJwt: String
        let handle: String
        let did: String
    }

    private func createSession(identifier: String, password: String) async throws -> Session {
        var req = URLRequest(url: Self.createSessionEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "identifier": identifier,
            "password": password
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw DelvetownError.http("createSession failed (\(snippet))")
        }
        let r = try JSONDecoder().decode(SessionResponse.self, from: data)
        return Session(accessJwt: r.accessJwt, refreshJwt: r.refreshJwt, handle: r.handle, did: r.did)
    }

    private func refreshSession(refreshJwt: String) async throws -> Session {
        var req = URLRequest(url: Self.refreshSessionEndpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(refreshJwt)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw DelvetownError.http("refreshSession failed (\(snippet))")
        }
        let r = try JSONDecoder().decode(SessionResponse.self, from: data)
        return Session(accessJwt: r.accessJwt, refreshJwt: r.refreshJwt, handle: r.handle, did: r.did)
    }

    private func deleteSession(refreshJwt: String) async throws {
        var req = URLRequest(url: Self.deleteSessionEndpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(refreshJwt)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: req)
    }

    private func persist(_ s: Session) {
        ClockTowerKeychain.set(s.accessJwt, for: .accessJwt)
        ClockTowerKeychain.set(s.refreshJwt, for: .refreshJwt)
        ClockTowerKeychain.set(s.handle, for: .handle)
        ClockTowerKeychain.set(s.did, for: .did)
        // Read the access JWT's `exp` claim for the true expiry; fall back to
        // 2h if the claim is missing or unparseable.
        let exp = Self.jwtExpiry(s.accessJwt) ?? Date().addingTimeInterval(7200)
        ClockTowerKeychain.set(ISO8601DateFormatter().string(from: exp), for: .accessJwtExpiry)
    }

    /// Decode a JWT's `exp` claim (seconds since epoch) without verifying the
    /// signature — we only need the expiry for refresh scheduling, not trust.
    private static func jwtExpiry(_ jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        payload = payload.replacingOccurrences(of: "-", with: "+")
                          .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}

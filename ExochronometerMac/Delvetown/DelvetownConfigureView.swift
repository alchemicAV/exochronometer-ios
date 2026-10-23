import SwiftUI

/// Sheet for setting Delvetown credentials, signing in (handle + ATProto app
/// password), and firing a test post to verify the whole pipeline end-to-end
/// before auto-posting triggers go live. No OAuth browser flow — ATProto
/// app passwords are exchanged directly against the PDS.
struct DelvetownConfigureView: View {
    @ObservedObject var auth: DelvetownAuthService = .shared
    @Environment(\.dismiss) private var dismiss

    @State private var handle: String = DelvetownKeychain.get(.handle) ?? ""
    @State private var appPassword: String = ""
    @State private var testResult: TestResult = .idle
    @State private var isTestingPost: Bool = false

    private enum TestResult: Equatable {
        case idle
        case posting
        case ok(URL)
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            credentialsBlock
            Divider()
            authBlock
            Divider()
            testBlock
            Spacer()
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Configure Delvetown")
                .font(.system(size: 15, weight: .medium))
            Text("ATProto app-password sign-in · credentials stored in macOS Keychain.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var credentialsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACCOUNT")
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            HStack {
                Text("Handle:")
                    .frame(width: 90, alignment: .trailing)
                TextField("you.delve.town", text: $handle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }
            HStack {
                Text("App Password:")
                    .frame(width: 90, alignment: .trailing)
                SecureField("from Delvetown settings", text: $appPassword)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }
            Text("Create an app password under Delvetown → Settings. This is not your login password.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var authBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AUTH STATE")
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            HStack {
                authStateIcon
                Text(authStateText)
                    .font(.system(size: 11))
                Spacer()
                switch auth.authState {
                case .signedIn:
                    Button("Sign out") { auth.signOut() }
                        .controlSize(.small)
                case .authorizing:
                    ProgressView()
                        .scaleEffect(0.5)
                default:
                    Button("Sign in") {
                        auth.signIn(handle: handle, appPassword: appPassword)
                    }
                    .controlSize(.small)
                    .disabled(handle.isEmpty || appPassword.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var testBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TEST POST")
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text("Posts a small \"Exochronometer test · <timestamp>\" message + a 256×256 PNG to verify the auth + blob + createRecord pipeline before triggers go live.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button {
                    Task { await runTestPost() }
                } label: {
                    Label("Send Test Post", systemImage: "paperplane.fill")
                }
                .disabled(!canTest || isTestingPost)
                if isTestingPost { ProgressView().scaleEffect(0.5) }
                Spacer()
            }
            testResultView
        }
    }

    @ViewBuilder
    private var testResultView: some View {
        switch testResult {
        case .idle:
            EmptyView()
        case .posting:
            Text("posting…")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        case .ok(let url):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Posted.")
                    .font(.system(size: 11))
                Link(url.absoluteString, destination: url)
                    .font(.system(size: 10, design: .monospaced))
            }
        case .failed(let msg):
            HStack(alignment: .top) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var canTest: Bool {
        if case .signedIn = auth.authState { return true }
        return false
    }

    private var authStateIcon: some View {
        Group {
            switch auth.authState {
            case .signedOut:
                Image(systemName: "person.crop.circle.badge.xmark")
                    .foregroundStyle(.secondary)
            case .authorizing:
                Image(systemName: "person.crop.circle.badge.clock")
                    .foregroundStyle(.orange)
            case .signedIn:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private var authStateText: String {
        switch auth.authState {
        case .signedOut:                  return "Not signed in."
        case .authorizing:                return "Signing in…"
        case .signedIn(let handle):       return "Signed in as @\(handle)"
        case .error(let msg):             return "Error: \(msg)"
        }
    }

    private func runTestPost() async {
        isTestingPost = true
        testResult = .posting
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let timestamp = formatter.string(from: Date())
            let text = "Exochronometer test · \(timestamp)"
            let image = Self.makeTestImagePNG(label: timestamp)
            let result = try await DelvetownAPIClient.shared.post(text: text, imagePNG: image)
            testResult = .ok(result.postURL)
        } catch {
            testResult = .failed(error.localizedDescription)
        }
        isTestingPost = false
    }

    /// Quick 256×256 PNG with the given label rendered onto a black canvas —
    /// enough to round-trip through the blob + record pipeline.
    private static func makeTestImagePNG(label: String) -> Data {
        let renderer = ImageRenderer(content:
            ZStack {
                Color.black
                VStack(spacing: 6) {
                    Text("EXOCHRONOMETER")
                        .font(.system(size: 14, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.white)
                    Text(label)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 256, height: 256)
        )
        renderer.scale = 1.0
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }
}

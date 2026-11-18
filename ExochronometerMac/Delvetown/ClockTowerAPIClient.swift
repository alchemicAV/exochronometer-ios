import AppKit
import Foundation

/// Thin wrapper over the ATProto XRPC endpoints for the SECOND delve.town
/// account (the daily clock tower). Identical to `DelvetownAPIClient` — same
/// `town.delve.feed.post` collection, same custom `town.delve.embed.images`
/// embed, same image-size guard — but reads the clock-tower session from
/// `ClockTowerKeychain`/`ClockTowerAuthService` so its posts go out under the
/// clock-tower account, not Octavia's.
@MainActor
final class ClockTowerAPIClient {
    static let shared = ClockTowerAPIClient()
    private init() {}

    private let uploadBlobEndpoint = URL(string: "https://pds.delve.town/xrpc/com.atproto.repo.uploadBlob")!
    private let createRecordEndpoint = URL(string: "https://pds.delve.town/xrpc/com.atproto.repo.createRecord")!

    static let postCollection = "town.delve.feed.post"
    static let postType = "town.delve.feed.post"
    static let embedImagesType = "town.delve.embed.images"

    struct PostResult {
        let uri: String
        let cid: String
        let rkey: String
        let postURL: URL
    }

    /// Create a post with optional image, optionally threaded as a reply to
    /// `replyTo`.
    func post(text: String, imagePNG: Data?, replyTo: PostResult? = nil) async throws -> PostResult {
        var embed: [String: Any]? = nil
        if let imagePNG {
            embed = try await makeImageEmbed(pngData: imagePNG)
        }
        return try await createRecord(text: text, embed: embed, replyTo: replyTo)
    }

    // MARK: images

    /// Upload the PNG bytes and build the `town.delve.embed.images` embed.
    /// The record validator caps an embedded image at ~2 MB — well below the
    /// PDS's general 5 MB blob ceiling — so anything near that limit is
    /// recompressed to JPEG first.
    private func makeImageEmbed(pngData: Data) async throws -> [String: Any] {
        let (payload, mimeType) = Self.imagePayload(forPNG: pngData)
        let blob = try await uploadBlob(payload, mimeType: mimeType)
        // upload_blob returns { "blob": { "$type": "blob", "ref": { "$link": <cid> }, "mimeType": …, "size": N } }
        guard let ref = blob["ref"] as? [String: Any], let cid = ref["$link"] as? String else {
            throw DelvetownError.unexpectedResponse("uploadBlob response missing ref.$link")
        }
        let mime = blob["mimeType"] as? String ?? mimeType
        let size = blob["size"] as? Int ?? payload.count
        let image: [String: Any] = [
            "$type": "blob",
            "ref": ["$link": cid],
            "mimeType": mime,
            "size": size
        ]
        // Image entry with alt text + pixel aspect ratio. Live delve.town
        // image posts all carry aspectRatio; some validators require it.
        var imageEntry: [String: Any] = ["image": image, "alt": ""]
        if let dims = Self.imageDimensions(payload) {
            imageEntry["aspectRatio"] = ["width": dims.width, "height": dims.height]
        }
        return [
            "$type": Self.embedImagesType,
            "images": [imageEntry]
        ]
    }

    private static func imageDimensions(_ data: Data) -> (width: Int, height: Int)? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return (rep.pixelsWide, rep.pixelsHigh)
    }

    private func uploadBlob(_ data: Data, mimeType: String) async throws -> [String: Any] {
        let token = try await ClockTowerAuthService.shared.currentAccessJwt()
        var req = URLRequest(url: uploadBlobEndpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (respData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: respData, encoding: .utf8) ?? ""
            throw DelvetownError.http("uploadBlob failed (\(snippet))")
        }
        guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
              let blob = json["blob"] as? [String: Any] else {
            throw DelvetownError.unexpectedResponse("uploadBlob response shape unknown")
        }
        return blob
    }

    // MARK: create record

    private func createRecord(text: String, embed: [String: Any]?, replyTo: PostResult?) async throws -> PostResult {
        guard let did = ClockTowerKeychain.get(.did) else {
            throw DelvetownError.notAuthenticated
        }
        let token = try await ClockTowerAuthService.shared.currentAccessJwt()

        var record: [String: Any] = [
            "$type": Self.postType,
            "text": text,
            "langs": ["en"],
            "createdAt": Self.utcTimestamp(Date())
        ]
        if let embed { record["embed"] = embed }
        if let replyTo {
            let parentRef: [String: Any] = ["uri": replyTo.uri, "cid": replyTo.cid]
            record["reply"] = ["root": parentRef, "parent": parentRef]
        }

        let body: [String: Any] = [
            "repo": did,
            "collection": Self.postCollection,
            "record": record
        ]
        var req = URLRequest(url: createRecordEndpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw DelvetownError.http("createRecord failed (\(snippet))")
        }
        struct Resp: Decodable { let uri: String; let cid: String }
        let parsed = try JSONDecoder().decode(Resp.self, from: data)
        let rkey = (parsed.uri as NSString).lastPathComponent
        let handle = ClockTowerKeychain.get(.handle) ?? "unknown"
        let url = URL(string: "https://delve.town/profile/\(handle)/post/\(rkey)")
            ?? URL(string: "https://delve.town")!
        return PostResult(uri: parsed.uri, cid: parsed.cid, rkey: rkey, postURL: url)
    }

    // MARK: helpers

    private static func utcTimestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    /// Returns the image bytes + mime type to upload. Same guard as
    /// `DelvetownAPIClient`: the post-record validator caps embedded images at
    /// ~2 MB, so anything near that limit is recompressed to JPEG first.
    static func imagePayload(forPNG pngData: Data) -> (data: Data, mimeType: String) {
        let limit = 1_950_000
        if pngData.count <= limit { return (pngData, "image/png") }

        // Recompress to JPEG at descending quality until it fits.
        var quality = 0.85
        while quality > 0.3 {
            if let jpeg = jpegData(fromPNG: pngData, quality: quality), jpeg.count <= limit {
                return (jpeg, "image/jpeg")
            }
            quality -= 0.15
        }

        // Still too big — downscale, then retry JPEG.
        if let scaled = downscaled(pngData, maxDimension: 1600),
           let jpeg = jpegData(fromPNG: scaled, quality: 0.8) {
            return (jpeg, "image/jpeg")
        }

        // Give up gracefully: return the original and let the PDS reject it
        // loudly rather than silently shipping a broken image.
        return (pngData, "image/png")
    }

    private static func jpegData(fromPNG pngData: Data, quality: Double) -> Data? {
        guard let rep = NSBitmapImageRep(data: pngData) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    private static func downscaled(_ pngData: Data, maxDimension: CGFloat) -> Data? {
        guard let image = NSImage(data: pngData) else { return nil }
        let size = image.size
        let scale = min(1.0, maxDimension / max(size.width, size.height))
        guard scale < 1.0 else { return pngData }
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        guard let tiff = newImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

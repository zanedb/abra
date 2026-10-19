import Foundation
import Kingfisher
import os
import UIKit
import UserNotifications

/// Owns match alerts and their tap destination independently of the song sheet.
final class MatchNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MatchNotificationService()

    static let openMatchNotification = Notification.Name("OpenMatchedSongNotification")

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "app.zane.abra", category: "MatchNotifications")
    private let artworkSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 1.2
        // A request timeout only limits idle time. Bound the whole download so
        // a trickling response cannot hold up the match notification indefinitely.
        configuration.timeoutIntervalForResource = 1.2
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()
    @MainActor private(set) var pendingMatchID: UUID?

    private override init() {
        super.init()
        center.delegate = self
    }

    func needsPermissionRequest() async -> Bool {
        await center.notificationSettings().authorizationStatus == .notDetermined
    }

    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func notify(
        title: String,
        artist: String,
        artworkURL: URL?,
        matchID: UUID
    ) async {
        let recognizedAt = Date()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = artist
        content.sound = .default
        content.userInfo = ["matchID": matchID.uuidString]

        var temporaryArtworkURL: URL?
        if let artworkURL, let (attachment, fileURL) = await artworkAttachment(from: artworkURL) {
            content.attachments = [attachment]
            temporaryArtworkURL = fileURL
        }
        defer {
            if let temporaryArtworkURL {
                try? FileManager.default.removeItem(at: temporaryArtworkURL)
            }
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
            logger.info("Match notification scheduled in \(Int(Date().timeIntervalSince(recognizedAt) * 1_000))ms; artwork attached: \(!content.attachments.isEmpty)")
        } catch {
            logger.error("Could not deliver match notification: \(error.localizedDescription)")
        }
    }

    func artworkAttachment(from url: URL) async -> (UNNotificationAttachment, URL)? {
        guard url.scheme == "https" else { return nil }
        do {
            // Share the same URL cache key as map pins, song rows, and SongView.
            // This reads both memory and disk without initiating another download.
            if let cached = try? await ImageCache.default.retrieveImage(forKey: url.cacheKey),
               let data = cached.image?.jpegData(compressionQuality: 0.9) {
                return try makeArtworkAttachment(data: data, fileExtension: "jpg")
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 1.2
            let (data, response) = try await artworkSession.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  data.count < 10_000_000 else { return nil }
            let fileExtension: String
            let attachmentData: Data
            switch response.mimeType?.lowercased() {
            case "image/jpeg", "image/jpg":
                fileExtension = "jpg"
                attachmentData = data
            case "image/png":
                fileExtension = "png"
                attachmentData = data
            case "image/gif":
                fileExtension = "gif"
                attachmentData = data
            default:
                guard let image = UIImage(data: data),
                      let jpeg = image.jpegData(compressionQuality: 0.85) else {
                    logger.debug("Unsupported artwork type: \(response.mimeType ?? "unknown")")
                    return nil
                }
                fileExtension = "jpg"
                attachmentData = jpeg
            }
            if let image = UIImage(data: attachmentData) {
                ImageCache.default.store(image, original: attachmentData, forKey: url.cacheKey, completionHandler: nil)
            }
            return try makeArtworkAttachment(data: attachmentData, fileExtension: fileExtension)
        } catch {
            logger.debug("Artwork unavailable for notification: \(error.localizedDescription)")
            return nil
        }
    }

    private func makeArtworkAttachment(data: Data, fileExtension: String) throws -> (UNNotificationAttachment, URL) {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        do {
            try data.write(to: fileURL, options: .atomic)
            return (try UNNotificationAttachment(identifier: "artwork", url: fileURL), fileURL)
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
    }

    @MainActor func clearPendingMatchID(if id: UUID) {
        if pendingMatchID == id { pendingMatchID = nil }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let id = response.notification.request.content.userInfo["matchID"] as? String,
              let uuid = UUID(uuidString: id) else {
            completionHandler()
            return
        }
        Task { @MainActor in
            pendingMatchID = uuid
            completionHandler()
            try? await Task.sleep(for: .milliseconds(300))
            NotificationCenter.default.post(name: Self.openMatchNotification, object: uuid)
        }
    }
}

import Foundation
import UIKit
import FirebaseStorage

enum PhotoStorageService {
    static func uploadAvatar(userId: String, imageData: Data, useLocalStore: Bool) async throws -> String {
        if useLocalStore {
            let dir = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("FoundryMeetAvatars", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("\(userId).jpg")
            try imageData.write(to: file, options: .atomic)
            return file.absoluteString
        }

        let ref = Storage.storage().reference().child("users/\(userId)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    static func deleteAvatar(userId: String, useLocalStore: Bool) async {
        if useLocalStore {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("FoundryMeetAvatars", isDirectory: true)
            let file = dir?.appendingPathComponent("\(userId).jpg")
            if let file {
                try? FileManager.default.removeItem(at: file)
            }
            return
        }
        let ref = Storage.storage().reference().child("users/\(userId)/avatar.jpg")
        try? await ref.delete()
    }

    static func jpegData(from image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

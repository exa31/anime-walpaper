import Foundation
import UIKit
import Photos

public final class PhotoSaver: NSObject {
    public static let shared = PhotoSaver()

    public func saveImageToPhotos(image: UIImage) async throws -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "PhotoSaver", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photos access was not granted."])
        }

        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}

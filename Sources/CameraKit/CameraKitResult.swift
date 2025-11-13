import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Rectangle expressed via normalized points (origin at top-left, range 0...1).
public struct CameraKitQuadrilateral: Equatable, Codable, Sendable {
    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomRight: CGPoint
    public var bottomLeft: CGPoint

    public init(topLeft: CGPoint,
                topRight: CGPoint,
                bottomRight: CGPoint,
                bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public var boundingBox: CGRect {
        let xs = [topLeft.x, topRight.x, bottomRight.x, bottomLeft.x]
        let ys = [topLeft.y, topRight.y, bottomRight.y, bottomLeft.y]
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public static func axisAligned(from rect: CGRect) -> CameraKitQuadrilateral {
        CameraKitQuadrilateral(
            topLeft: rect.origin,
            topRight: CGPoint(x: rect.maxX, y: rect.minY),
            bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        )
    }
}

public struct CameraKitMetadata: Equatable, Codable, Sendable {
    public var timestamp: Date
    public var deviceOrientation: Int
    public var isFromPhotoLibrary: Bool
    public var extras: [String: String]

    public init(timestamp: Date = Date(),
                deviceOrientation: Int = 0,
                isFromPhotoLibrary: Bool = false,
                extras: [String: String] = [:]) {
        self.timestamp = timestamp
        self.deviceOrientation = deviceOrientation
        self.isFromPhotoLibrary = isFromPhotoLibrary
        self.extras = extras
    }
}

#if canImport(UIKit)
public struct CameraKitResult {
    public let processedImage: UIImage
    public let originalImage: UIImage?
    public let detectedRectangle: CameraKitQuadrilateral?
    public let adjustedRectangle: CameraKitQuadrilateral?
    public let enhancement: CameraKitEnhancement
    public let metadata: CameraKitMetadata
    public let context: CameraKitContext?
    public let jpegData: Data?

    public init(processedImage: UIImage,
                originalImage: UIImage?,
                detectedRectangle: CameraKitQuadrilateral?,
                adjustedRectangle: CameraKitQuadrilateral?,
                enhancement: CameraKitEnhancement,
                metadata: CameraKitMetadata,
                context: CameraKitContext?,
                jpegData: Data?) {
        self.processedImage = processedImage
        self.originalImage = originalImage
        self.detectedRectangle = detectedRectangle
        self.adjustedRectangle = adjustedRectangle
        self.enhancement = enhancement
        self.metadata = metadata
        self.context = context
        self.jpegData = jpegData
    }
}
#endif

public enum CameraKitError: Error, Equatable, Sendable {
    case permissionDenied
    case cameraUnavailable
    case captureFailed(reason: String)
    case processingFailed
}

#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
extension CameraKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return CameraKitLocalization.string("camera_kit_permission_denied")
        case .cameraUnavailable:
            return CameraKitLocalization.string("camera_kit_camera_unavailable")
        case .captureFailed(let reason):
            return "\(CameraKitLocalization.string("camera_kit_error_generic")) (\(reason))"
        case .processingFailed:
            return CameraKitLocalization.string("camera_kit_error_generic")
        }
    }
}
#endif

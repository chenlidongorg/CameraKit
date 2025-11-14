import CoreGraphics
import Foundation

/// Represents the supported capture modes.
public enum CameraKitMode: Equatable, Sendable {
    /// Real-time adjustable capture area prior to shutter.
    case realTime
    /// Standard single-shot capture that returns the full frame.
    case photo
    /// Standard capture followed by a manual crop step.
    case photoWithCrop
    /// Single-page scan flow powered by `VNDocumentCameraViewController`.
    case scanSingle
    /// Multi-page scan flow powered by `VNDocumentCameraViewController`.
    case scanBatch
}

/// Configures the automatic enhancement strategy applied to captured assets.
public enum CameraKitEnhancement: Equatable, Sendable {
    case none
    case auto
    case grayscale
}

/// Defines the flash mode used for the shutter action.
public enum CameraKitFlashMode: Equatable, CaseIterable, Sendable {
    case auto
    case on
    case off
}

/// Output quality descriptor for the processed image.
public struct CameraKitOutputQuality: Equatable, Sendable {
    public var targetResolution: CGSize?
    public var compressionQuality: CGFloat
    public var maxOutputWidth: CGFloat?

    public init(targetResolution: CGSize? = nil,
                compressionQuality: CGFloat = 0.85,
                maxOutputWidth: CGFloat? = nil) {
        self.targetResolution = targetResolution
        self.compressionQuality = min(max(compressionQuality, 0.0), 1.0)
        self.maxOutputWidth = maxOutputWidth
    }
}

/// Arbitrary context passed through the flow and mirrored in the callback result.
public struct CameraKitContext: Equatable, Codable, Sendable {
    public var identifier: String
    public var payload: [String: String]

    public init(identifier: String, payload: [String: String] = [:]) {
        self.identifier = identifier
        self.payload = payload
    }
}

/// Top-level configuration entry used when constructing the launcher.
public struct CameraKitConfiguration: Equatable, Sendable {
    public var mode: CameraKitMode
    public var enableLiveDetectionOverlay: Bool
    public var allowsPostCaptureCropping: Bool
    public var enhancement: CameraKitEnhancement
    public var allowsPhotoLibraryImport: Bool
    public var outputQuality: CameraKitOutputQuality
    public var context: CameraKitContext?
    public var defaultFlashMode: CameraKitFlashMode
    public var metadata: [String: String]

    public init(mode: CameraKitMode = .photo,
                enableLiveDetectionOverlay: Bool = true,
                allowsPostCaptureCropping: Bool = false,
                enhancement: CameraKitEnhancement = .none,
                allowsPhotoLibraryImport: Bool = true,
                outputQuality: CameraKitOutputQuality = .init(),
                context: CameraKitContext? = nil,
                defaultFlashMode: CameraKitFlashMode = .auto,
                metadata: [String: String] = [:]) {
        self.mode = mode
        self.enableLiveDetectionOverlay = enableLiveDetectionOverlay
        self.allowsPostCaptureCropping = allowsPostCaptureCropping
        self.enhancement = enhancement
        self.allowsPhotoLibraryImport = allowsPhotoLibraryImport
        self.outputQuality = outputQuality
        self.context = context
        self.defaultFlashMode = defaultFlashMode
        self.metadata = metadata
    }
}

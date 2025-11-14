#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
#if !targetEnvironment(macCatalyst)
import AVFoundation
#endif
import UIKit
#if canImport(VisionKit)
import VisionKit
#endif


enum CameraKitDeviceEnvironment {
    static var isMacCatalyst: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    #if targetEnvironment(macCatalyst)
    static func hasBuiltInCamera() -> Bool { false }

    static func hasAnyCamera() -> Bool { false }
    #else
    static func hasBuiltInCamera() -> Bool {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: builtInDeviceTypes,
                                                       mediaType: .video,
                                                       position: .unspecified)
        return !session.devices.isEmpty
    }

    static func externalCameraDevices() -> [AVCaptureDevice] {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: builtInDeviceTypes,
                                                       mediaType: .video,
                                                       position: .unspecified)
        return session.devices.filter { $0.position == .unspecified }
    }

    static func hasAnyCamera() -> Bool {
        hasBuiltInCamera() || !externalCameraDevices().isEmpty
    }
    #endif

    static func supportsDocumentScanner() -> Bool {
        #if canImport(VisionKit)
        guard !isMacCatalyst else { return false }
        if #available(iOS 13.0, *) {
            return VNDocumentCameraViewController.isSupported
        }
        return false
        #else
        return false
        #endif
    }

    static func allowsMultipleSelection(for mode: CameraKitMode) -> Bool {
        switch mode {
        case .scanBatch:
            return true
        default:
            return false
        }
    }

    static func shouldFallbackToPicker(for mode: CameraKitMode) -> Bool {
        if isMacCatalyst { return true }
        if !hasAnyCamera() {
            return true
        }
        return false
    }
}

#if !targetEnvironment(macCatalyst)
private extension CameraKitDeviceEnvironment {
    static var builtInDeviceTypes: [AVCaptureDevice.DeviceType] {
        [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera
        ]
    }
}
#endif
#endif

#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import AVFoundation
import SwiftUI

@available(iOS 14.0, *)
struct CameraKitPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onLayerUpdate: ((AVCaptureVideoPreviewLayer) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        onLayerUpdate?(view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        onLayerUpdate?(uiView.videoPreviewLayer)
    }
}

@available(iOS 14.0, *)
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
#endif

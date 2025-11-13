#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import AVFoundation
import UIKit
import SwiftUI

struct CameraKitExperienceView: View {
    private let viewModel: CameraKitViewModel

    init(configuration: CameraKitConfiguration,
         onResult: @escaping (CameraKitResult) -> Void,
         onCancel: @escaping () -> Void,
         onError: @escaping (CameraKitError) -> Void) {
        self.viewModel = CameraKitViewModel(configuration: configuration,
                                            onResult: onResult,
                                            onCancel: onCancel,
                                            onError: onError)
    }

    var body: some View {
        CameraKitExperienceContent()
            .environmentObject(viewModel)
    }
}

private struct CameraKitExperienceContent: View {
    @EnvironmentObject private var viewModel: CameraKitViewModel

    var body: some View {
        ZStack {
            CameraKitPreviewView(session: viewModel.session)
                .edgesIgnoringSafeArea(.all)

            if viewModel.configuration.enableLiveDetectionOverlay, let detection = viewModel.detection {
                DetectionOverlayShape(quadrilateral: detection)
                    .stroke(Color.green.opacity(0.8), lineWidth: 2)
                    .padding()
            }

            overlayControls

            if viewModel.isProcessing {
                ProcessingOverlay()
            }
        }
        .sheet(item: $viewModel.manualCropContext) { context in
            CameraKitCropView(image: context.image,
                              initialRect: context.initialRect,
                              onCancel: {
                                  viewModel.cancelManualCrop()
                              }, onConfirm: { rect in
                                  viewModel.commitManualCrop(rect: rect, captureID: context.id)
                              })
        }
        .sheet(isPresented: $viewModel.isPhotoPickerPresented) {
            SystemImagePicker(onPick: { image in
                viewModel.handleImportedImage(image)
            }, onCancel: {
                viewModel.isPhotoPickerPresented = false
            })
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var overlayControls: some View {
        VStack {
            topBar
            Spacer()
            if viewModel.configuration.enableLiveDetectionOverlay {
                Text(CameraKitLocalization.string("camera_kit_live_detection"))
                    .font(.footnote)
                    .padding(8)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
            bottomBar
        }
        .padding()
        .foregroundColor(.white)
    }

    private var topBar: some View {
        HStack {
            Button(action: { viewModel.cancelFlow() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
                    .accessibility(label: Text(CameraKitLocalization.string("camera_kit_cancel")))
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: { viewModel.toggleFlashMode() }) {
                    Text(viewModel.flashLabel)
                        .font(.subheadline).bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                }

                Button(action: { viewModel.flipCamera() }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                        .accessibility(label: Text(CameraKitLocalization.string("camera_kit_flip_camera")))
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 24) {
            if viewModel.configuration.allowsPhotoLibraryImport {
                Button(action: { viewModel.presentPhotoPicker() }) {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(CameraKitLocalization.string("camera_kit_album_import")).font(.caption)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()

            Button(action: { viewModel.capture() }) {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().fill(Color.white.opacity(0.2)).padding(6))
            }
            .disabled(viewModel.isProcessing)

        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.45).edgesIgnoringSafeArea(.all)
            VStack(spacing: 8) {
                ActivityIndicator()
                Text(CameraKitLocalization.string("camera_kit_processing"))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct DetectionOverlayShape: Shape {
    let quadrilateral: CameraKitQuadrilateral

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = [quadrilateral.topLeft, quadrilateral.topRight, quadrilateral.bottomRight, quadrilateral.bottomLeft]
            .map { CGPoint(x: $0.x * rect.width, y: $0.y * rect.height) }

        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: first)
        return path
    }
}

@MainActor
final class CameraKitViewModel: NSObject, ObservableObject {
    @Published var detection: CameraKitQuadrilateral?
    @Published var isProcessing = false
    @Published var isPhotoPickerPresented = false
    @Published var manualCropContext: ManualCropContext?
    @Published var alert: CameraAlert?
    @Published private(set) var flashMode: CameraKitFlashMode

    let configuration: CameraKitConfiguration
    private let onResult: (CameraKitResult) -> Void
    private let onCancel: () -> Void
    private let onError: (CameraKitError) -> Void
    private let captureCoordinator: CameraKitCaptureCoordinator

    struct ManualCropContext: Identifiable {
        let id = UUID()
        let image: UIImage
        let initialRect: CGRect
        let detection: CameraKitQuadrilateral?
    }

    struct CameraAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var session: AVCaptureSession { captureCoordinator.session }

    init(configuration: CameraKitConfiguration,
         onResult: @escaping (CameraKitResult) -> Void,
         onCancel: @escaping () -> Void,
         onError: @escaping (CameraKitError) -> Void) {
        self.configuration = configuration
        self.onResult = onResult
        self.onCancel = onCancel
        self.onError = onError
        self.captureCoordinator = CameraKitCaptureCoordinator(configuration: configuration)
        self.flashMode = configuration.defaultFlashMode
        super.init()
        captureCoordinator.delegate = self
    }

    var flashLabel: String {
        switch flashMode {
        case .auto:
            return CameraKitLocalization.string("camera_kit_flash_auto")
        case .on:
            return CameraKitLocalization.string("camera_kit_flash_on")
        case .off:
            return CameraKitLocalization.string("camera_kit_flash_off")
        }
    }

    func start() {
        captureCoordinator.startSession()
    }

    func stop() {
        captureCoordinator.stopSession()
    }

    func capture() {
        guard !isProcessing else { return }
        isProcessing = true
        captureCoordinator.setFlashMode(flashMode)
        captureCoordinator.capturePhoto()
    }

    func cancelFlow() {
        stop()
        onCancel()
    }

    func toggleFlashMode() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        case .off: flashMode = .auto
        }
    }

    func flipCamera() {
        captureCoordinator.flipCamera()
    }

    func presentPhotoPicker() {
        isPhotoPickerPresented = true
    }

    func handleImportedImage(_ image: UIImage) {
        isPhotoPickerPresented = false
        process(image: image, detection: nil, isFromLibrary: true)
    }

    func cancelManualCrop() {
        manualCropContext = nil
        isProcessing = false
    }

    func commitManualCrop(rect: CGRect, captureID: UUID) {
        guard let context = manualCropContext, context.id == captureID else { return }
        let quad = CameraKitQuadrilateral.axisAligned(from: rect)
        manualCropContext = nil
        process(image: context.image, detection: context.detection, manualRectangle: quad, isFromLibrary: false)
    }

    private func process(image: UIImage,
                         detection: CameraKitQuadrilateral?,
                         manualRectangle: CameraKitQuadrilateral? = nil,
                         isFromLibrary: Bool) {
        isProcessing = true
        Task {
            let pipeline = CameraKitProcessingPipeline(configuration: configuration)
            do {
                let result = try await pipeline.process(image: image,
                                                        detection: detection,
                                                        manualRectangle: manualRectangle,
                                                        isFromLibrary: isFromLibrary)
                isProcessing = false
                onResult(result)
            } catch let error as CameraKitError {
                isProcessing = false
                alert = CameraAlert(title: CameraKitLocalization.string("camera_kit_error_generic"),
                                    message: error.localizedDescription)
                onError(error)
            } catch {
                isProcessing = false
                let err = CameraKitError.processingFailed
                alert = CameraAlert(title: CameraKitLocalization.string("camera_kit_error_generic"),
                                    message: error.localizedDescription)
                onError(err)
            }
        }
    }
}

extension CameraKitViewModel: CameraKitCaptureCoordinatorDelegate {
    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didUpdate detection: CameraKitQuadrilateral?) {
        self.detection = detection
    }

    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didCapture image: UIImage, detection: CameraKitQuadrilateral?) {
        Task { @MainActor in
            self.isProcessing = false
            if configuration.allowsPostCaptureCropping {
                let rect = detection?.boundingBox ?? CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                self.manualCropContext = ManualCropContext(image: image, initialRect: rect, detection: detection)
            } else {
                self.process(image: image, detection: detection, manualRectangle: nil, isFromLibrary: false)
            }
        }
    }

    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didFail error: CameraKitError) {
        isProcessing = false
        alert = CameraAlert(title: CameraKitLocalization.string("camera_kit_error_generic"),
                            message: error.localizedDescription)
        onError(error)
    }
}

struct SystemImagePicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: SystemImagePicker

        init(parent: SystemImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onCancel()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            } else {
                parent.onCancel()
            }
        }
    }
}

private struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: .large)
        view.color = .white
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}
#endif

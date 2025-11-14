#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import AVFoundation
import UIKit
import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(MobileCoreServices)
import MobileCoreServices
#endif
#if canImport(VisionKit)
import VisionKit
#endif

@available(iOS 14.0, *)
struct CameraKitExperienceView: View {
    private let viewModel: CameraKitViewModel

    init(configuration: CameraKitConfiguration,
         onResult: @escaping ([UIImage]) -> Void,
         onOriginalImageResult: (([UIImage]) -> Void)? = nil,
         onCancel: @escaping () -> Void,
         onError: @escaping (CameraKitError) -> Void) {
        self.viewModel = CameraKitViewModel(configuration: configuration,
                                            onResult: onResult,
                                            onOriginalImageResult: onOriginalImageResult,
                                            onCancel: onCancel,
                                            onError: onError)
    }

    var body: some View {
        CameraKitExperienceContent()
            .environmentObject(viewModel)
    }
}

@available(iOS 14.0, *)
private struct CameraKitExperienceContent: View {
    @EnvironmentObject private var viewModel: CameraKitViewModel

    var body: some View {
        ZStack {
            flowView
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
        #if canImport(PhotosUI)
        .sheet(isPresented: $viewModel.isPhotoPickerPresented) {
            if #available(iOS 14.0, macCatalyst 14.0, *) {
                SystemImagePicker(selectionLimit: viewModel.photoPickerSelectionLimit) { images in
                    viewModel.handleImportedImages(images)
                } onCancel: {
                    viewModel.isPhotoPickerPresented = false
                }
            } else {
                EmptyView()
            }
        }
        #endif
        .sheet(isPresented: $viewModel.isFileImporterPresented) {
            SystemFilePicker(allowsMultipleSelection: viewModel.flow.allowsMultipleSelection) { urls in
                viewModel.handleImportedFiles(urls: urls)
            } onCancel: {
                viewModel.isFileImporterPresented = false
            }
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        #if !targetEnvironment(macCatalyst)
        .actionSheet(isPresented: Binding(get: {
            viewModel.continuityPrompt != nil
        }, set: { newValue in
            if !newValue {
                viewModel.dismissContinuityPrompt()
            }
        })) {
            let title = Text(CameraKitLocalization.string("camera_kit_select_device"))
            let devices = viewModel.continuityPrompt?.devices ?? []
            var buttons: [ActionSheet.Button] = devices.map { device in
                .default(Text(device.localizedName)) {
                    viewModel.useContinuityDevice(device)
                }
            }
            buttons.append(.cancel {
                viewModel.dismissContinuityPrompt()
            })
            return ActionSheet(title: title, buttons: buttons)
        }
        #endif
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    @ViewBuilder
    private var cameraExperience: some View {
        ZStack {
            if let session = viewModel.session {
                CameraKitMeasuredPreviewView(session: session) { size in
                    viewModel.updatePreviewSize(size)
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }

            if viewModel.configuration.enableLiveDetectionOverlay, let detection = viewModel.detection {
                DetectionOverlayShape(quadrilateral: detection)
                    .stroke(Color.green.opacity(0.8), lineWidth: 2)
                    .ignoresSafeArea()
            }

            if viewModel.configuration.mode == .realTime {
                CameraKitNormalizedCropOverlay(cropRect: $viewModel.liveCropRect,
                                               dimmingColor: Color.black.opacity(0.1),
                                               strokeColor: .yellow,
                                               handleColor: .white)
                    .ignoresSafeArea()
            }

            overlayControls
        }
    }

    @ViewBuilder
    private var flowView: some View {
        switch viewModel.flow {
        case .camera:
            cameraExperience
        case .scannerSingle:
            #if canImport(VisionKit)
            CameraKitScannerFlowView(allowsMultiple: false)
            #else
            ScannerPlaceholderView()
            #endif
        case .scannerBatch:
            #if canImport(VisionKit)
            CameraKitScannerFlowView(allowsMultiple: true)
            #else
            ScannerPlaceholderView()
            #endif
        case .picker(let allowsMultiple):
            PickerFallbackView(allowsMultiple: allowsMultiple)
        }
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
            if viewModel.shouldShowPhotoLibraryButton {
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

@available(iOS 14.0, *)
private struct ScannerPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(CameraKitLocalization.string("camera_kit_scanner_launching"))
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 14.0, *)
private struct PickerFallbackView: View {
    @EnvironmentObject private var viewModel: CameraKitViewModel
    let allowsMultiple: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text(CameraKitLocalization.string("camera_kit_picker_title"))
                .font(.headline)

            Text(CameraKitLocalization.string("camera_kit_picker_subtitle"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                if viewModel.supportsPhotoPicker {
                    Button {
                        viewModel.presentPhotoPicker(allowsMultiple: allowsMultiple)
                    } label: {
                        pickerButtonLabel(systemName: "photo.on.rectangle.angled",
                                          title: CameraKitLocalization.string("camera_kit_album_import"))
                    }
                }
                Button {
                    viewModel.presentFileImporter()
                } label: {
                    pickerButtonLabel(systemName: "folder",
                                      title: CameraKitLocalization.string("camera_kit_file_import"))
                }
            }

            Button(CameraKitLocalization.string("camera_kit_cancel")) {
                viewModel.cancelFlow()
            }
            .foregroundColor(.red)
        }
        .padding()
    }

    @ViewBuilder
    private func pickerButtonLabel(systemName: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).bold()
                Text(allowsMultiple
                     ? CameraKitLocalization.string("camera_kit_picker_multi_hint")
                     : CameraKitLocalization.string("camera_kit_picker_single_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}

private extension Array {
    func element(at index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#if canImport(VisionKit)
@available(iOS 14.0, *)
private struct CameraKitScannerFlowView: View {
    @EnvironmentObject private var viewModel: CameraKitViewModel
    let allowsMultiple: Bool

    var body: some View {
        CameraKitDocumentScannerView { images in
            viewModel.handleScannedImages(images, allowsMultiple: allowsMultiple)
        } onCancel: {
            viewModel.cancelFlow()
        } onError: { error in
            viewModel.handleScannerError(error)
        }
    }
}
#endif
@available(iOS 14.0, *)
private extension CameraKitViewModel.Flow {
    var allowsMultipleSelection: Bool {
        switch self {
        case .picker(let allowsMultiple):
            return allowsMultiple
        case .scannerBatch:
            return true
        default:
            return false
        }
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

@available(iOS 14.0, *)
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

@available(iOS 14.0, *)
private struct CameraKitMeasuredPreviewView: View {
    let session: AVCaptureSession
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        GeometryReader { geometry in
            CameraKitPreviewView(session: session)
                .onAppear { reportSize(geometry.size) }
                .onChange(of: geometry.size) { newValue in
                    reportSize(newValue)
                }
        }
    }

    private func reportSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        DispatchQueue.main.async {
            onSizeChange(size)
        }
    }
}

@available(iOS 14.0, *)
@MainActor
final class CameraKitViewModel: NSObject, ObservableObject {
    enum Flow: Equatable {
        case camera
        case scannerSingle
        case scannerBatch
        case picker(allowsMultiple: Bool)
    }

    @Published var detection: CameraKitQuadrilateral?
    @Published var isProcessing = false
    @Published var isPhotoPickerPresented = false
    @Published var isFileImporterPresented = false
    @Published var manualCropContext: ManualCropContext?
    @Published var alert: CameraAlert?
    @Published private(set) var flashMode: CameraKitFlashMode
    #if !targetEnvironment(macCatalyst)
    @Published var continuityPrompt: ContinuityPrompt?
    #endif
    @Published var liveCropRect: CGRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @Published private(set) var previewSize: CGSize = .zero

    let configuration: CameraKitConfiguration
    let flow: Flow
    private let onResult: ([UIImage]) -> Void
    private let onOriginalImageResult: (([UIImage]) -> Void)?
    private let onCancel: () -> Void
    private let onError: (CameraKitError) -> Void
    private let captureCoordinator: CameraKitCaptureCoordinator?
    #if !targetEnvironment(macCatalyst)
    private let continuityDevices: [AVCaptureDevice]
    #endif
    private var currentPhotoPickerSelectionLimit = 1

    struct ManualCropContext: Identifiable {
        let id = UUID()
        let image: UIImage
        let initialRect: CGRect
        let detection: CameraKitQuadrilateral?
        let isFromLibrary: Bool
    }

    struct CameraAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    #if !targetEnvironment(macCatalyst)
    struct ContinuityPrompt: Identifiable {
        let id = UUID()
        let devices: [AVCaptureDevice]
    }
    #endif

    var session: AVCaptureSession? { captureCoordinator?.session }

    init(configuration: CameraKitConfiguration,
         onResult: @escaping ([UIImage]) -> Void,
         onOriginalImageResult: (([UIImage]) -> Void)? = nil,
         onCancel: @escaping () -> Void,
         onError: @escaping (CameraKitError) -> Void) {
        self.configuration = configuration
        self.onResult = onResult
        self.onOriginalImageResult = onOriginalImageResult
        self.onCancel = onCancel
        self.onError = onError
        let resolvedFlow = CameraKitViewModel.resolveFlow(for: configuration)
        self.flow = resolvedFlow
        if case .camera = resolvedFlow {
            let coordinator = CameraKitCaptureCoordinator(configuration: configuration)
            self.captureCoordinator = coordinator
        } else {
            self.captureCoordinator = nil
        }
#if !targetEnvironment(macCatalyst)
        self.continuityDevices = CameraKitDeviceEnvironment.externalCameraDevices()
#endif
        self.flashMode = configuration.defaultFlashMode
        super.init()
        if configuration.mode == .realTime {
            self.liveCropRect = CameraKitViewModel.initialLiveCropRect(for: configuration)
        }
        captureCoordinator?.delegate = self
    }

    private static func resolveFlow(for configuration: CameraKitConfiguration) -> Flow {
        switch configuration.mode {
        case .scanSingle:
            if CameraKitDeviceEnvironment.supportsDocumentScanner() {
                return .scannerSingle
            } else {
                return .picker(allowsMultiple: false)
            }
        case .scanBatch:
            if CameraKitDeviceEnvironment.supportsDocumentScanner() {
                return .scannerBatch
            } else {
                return .picker(allowsMultiple: true)
            }
        case .realTime, .photo, .photoWithCrop:
            if CameraKitDeviceEnvironment.shouldFallbackToPicker(for: configuration.mode) {
                return .picker(allowsMultiple: CameraKitDeviceEnvironment.allowsMultipleSelection(for: configuration.mode))
            } else {
                return .camera
            }
        }
    }

    private static func initialLiveCropRect(for configuration: CameraKitConfiguration) -> CGRect {
        let width: CGFloat = 0.8
        let height = configuration.defaultRealtimeHeight
        let x = max(0, (1 - width) / 2)
        let y = max(0, (1 - height) / 2)
        return CGRect(x: x, y: y, width: width, height: height).clampedRect()
    }

    private func liveCropRectForImage(imageSize: CGSize) -> CGRect {
        guard previewSize.width > 0,
              previewSize.height > 0,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return liveCropRect.clampedRect()
        }

        let rect = liveCropRect.clampedRect()
        let viewRect = rect.denormalized(in: previewSize)
        let previewAspect = previewSize.width / previewSize.height
        let imageAspect = imageSize.width / imageSize.height

        var scale: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if imageAspect > previewAspect {
            scale = previewSize.height / imageSize.height
            let scaledWidth = imageSize.width * scale
            offsetX = (scaledWidth - previewSize.width) / 2
        } else {
            scale = previewSize.width / imageSize.width
            let scaledHeight = imageSize.height * scale
            offsetY = (scaledHeight - previewSize.height) / 2
        }

        let scaledRect = CGRect(x: viewRect.origin.x + offsetX,
                                y: viewRect.origin.y + offsetY,
                                width: viewRect.width,
                                height: viewRect.height)
        let imageRect = CGRect(x: scaledRect.origin.x / scale,
                               y: scaledRect.origin.y / scale,
                               width: scaledRect.width / scale,
                               height: scaledRect.height / scale)
        let normalized = CGRect(x: imageRect.origin.x / imageSize.width,
                                y: imageRect.origin.y / imageSize.height,
                                width: imageRect.width / imageSize.width,
                                height: imageRect.height / imageSize.height)
        logLiveCropDebug(previewRect: viewRect,
                         scaledRect: scaledRect,
                         imageRect: imageRect,
                         normalizedRect: normalized,
                         scale: scale,
                         offsets: (offsetX, offsetY),
                         imageSize: imageSize)
        return normalized.clampedRect()
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

    var supportsPhotoPicker: Bool {
        #if canImport(PhotosUI)
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 14.0, *) {
            return true
        } else {
            return false
        }
        #else
        if #available(iOS 14.0, *) {
            return true
        } else {
            return false
        }
        #endif
        #else
        return false
        #endif
    }

    func updatePreviewSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if previewSize != size {
            previewSize = size
        }
    }

    var shouldShowPhotoLibraryButton: Bool {
        configuration.allowsPhotoLibraryImport && supportsPhotoPicker
    }

    private var shouldPresentManualCrop: Bool {
        configuration.mode == .photoWithCrop || configuration.allowsPostCaptureCropping
    }

    func start() {
        if flow == .camera {
            captureCoordinator?.startSession()
            #if !targetEnvironment(macCatalyst)
            maybePromptForContinuity()
            #endif
        }
    }

    func stop() {
        captureCoordinator?.stopSession()
    }

    func capture() {
        guard !isProcessing else { return }
        guard flow == .camera else { return }
        isProcessing = true
        captureCoordinator?.setFlashMode(flashMode)
        captureCoordinator?.capturePhoto()
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
        captureCoordinator?.flipCamera()
    }

    var photoPickerSelectionLimit: Int { currentPhotoPickerSelectionLimit }

    func presentPhotoPicker(allowsMultiple: Bool = false) {
        guard supportsPhotoPicker else {
            isPhotoPickerPresented = false
            return
        }
        #if canImport(PhotosUI)
        if #available(iOS 14.0, macCatalyst 14.0, *) {
            currentPhotoPickerSelectionLimit = allowsMultiple ? 0 : 1
            isPhotoPickerPresented = true
        } else {
            isPhotoPickerPresented = false
        }
        #else
        isPhotoPickerPresented = false
        #endif
    }

    func presentFileImporter() {
        isFileImporterPresented = true
    }

    func handleImportedImages(_ images: [UIImage]) {
        isPhotoPickerPresented = false
        processImported(images: images, isFromLibrary: true)
    }

    func handleImportedFiles(urls: [URL]) {
        guard !urls.isEmpty else {
            isFileImporterPresented = false
            return
        }

        Task.detached(priority: .userInitiated) {
            var images: [UIImage] = []
            for url in urls {
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }

            await MainActor.run {
                self.isFileImporterPresented = false
                self.processImported(images: images, isFromLibrary: true)
            }
        }
    }

    func cancelManualCrop() {
        manualCropContext = nil
        isProcessing = false
    }

    func commitManualCrop(rect: CGRect, captureID: UUID) {
        guard let context = manualCropContext, context.id == captureID else { return }
        let quad = CameraKitQuadrilateral.axisAligned(from: rect)
        manualCropContext = nil
        process(image: context.image,
                detection: context.detection,
                manualRectangle: quad,
                isFromLibrary: context.isFromLibrary)
    }

    private func processImported(images: [UIImage], isFromLibrary: Bool) {
        guard !images.isEmpty else { return }
        if shouldPresentManualCrop, let image = images.first {
            manualCropContext = ManualCropContext(image: image,
                                                  initialRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                                                  detection: nil,
                                                  isFromLibrary: isFromLibrary)
            return
        }

        if images.count == 1, let first = images.first {
            process(image: first, detection: nil, manualRectangle: nil, isFromLibrary: isFromLibrary)
        } else {
            process(images: images, isFromLibrary: isFromLibrary)
        }
    }

    func handleScannedImages(_ images: [UIImage], allowsMultiple: Bool) {
        guard !images.isEmpty else {
            cancelFlow()
            return
        }
        let payload = allowsMultiple ? images : Array(images.prefix(1))
        process(images: payload, isFromLibrary: false)
    }

    func handleScannerError(_ error: Error) {
        handleProcessingFailure(error: .captureFailed(reason: error.localizedDescription),
                                message: error.localizedDescription)
    }

    private func process(image: UIImage,
                         detection: CameraKitQuadrilateral?,
                         manualRectangle: CameraKitQuadrilateral? = nil,
                         isFromLibrary: Bool) {
        let detections: [CameraKitQuadrilateral?] = [detection]
        let manualRects: [CameraKitQuadrilateral?] = [manualRectangle]
        process(images: [image],
                detections: detections,
                manualRectangles: manualRects,
                isFromLibrary: isFromLibrary)
    }

    private func process(images: [UIImage],
                         detections: [CameraKitQuadrilateral?] = [],
                         manualRectangles: [CameraKitQuadrilateral?] = [],
                         isFromLibrary: Bool) {
        guard !images.isEmpty else { return }
        isProcessing = true
        Task {
            let pipeline = CameraKitProcessingPipeline(configuration: configuration)
            do {
                var processed: [UIImage] = []
                for (index, image) in images.enumerated() {
                    let detection = detections.element(at: index) ?? nil
                    let manual = manualRectangles.element(at: index) ?? nil
                    let result = try await pipeline.process(image: image,
                                                            detection: detection,
                                                            manualRectangle: manual,
                                                            isFromLibrary: isFromLibrary)
                    processed.append(result)
                }
                isProcessing = false
                onResult(processed)
                onOriginalImageResult?(images)
            } catch let error as CameraKitError {
                handleProcessingFailure(error: error)
            } catch {
                handleProcessingFailure(error: .processingFailed, message: error.localizedDescription)
            }
        }
    }

    #if !targetEnvironment(macCatalyst)
    private func maybePromptForContinuity() {
        guard flow == .camera else { return }
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        guard !continuityDevices.isEmpty else { return }
        continuityPrompt = ContinuityPrompt(devices: continuityDevices)
    }
    #endif

    private func handleProcessingFailure(error: CameraKitError, message: String? = nil) {
        isProcessing = false
        alert = CameraAlert(title: CameraKitLocalization.string("camera_kit_error_generic"),
                            message: message ?? error.localizedDescription)
        onError(error)
    }

    private var shouldLogLiveCrop: Bool {
        guard let flag = configuration.metadata["log_live_crop"]?.lowercased() else { return false }
        return flag == "1" || flag == "true" || flag == "yes"
    }

    private func logLiveCropDebug(previewRect: CGRect,
                                  scaledRect: CGRect,
                                  imageRect: CGRect,
                                  normalizedRect: CGRect,
                                  scale: CGFloat,
                                  offsets: (x: CGFloat, y: CGFloat),
                                  imageSize: CGSize) {
        guard shouldLogLiveCrop else { return }
        let message = """
        [CameraKit][LiveCrop] previewSize=\(previewSize), imageSize=\(imageSize), scale=\(scale), \
offsetX=\(offsets.x), offsetY=\(offsets.y), previewRect=\(previewRect), scaledRect=\(scaledRect), \
imageRect=\(imageRect), normalizedRect=\(normalizedRect)
"""
        print(message)
    }

    #if !targetEnvironment(macCatalyst)
    func useContinuityDevice(_ device: AVCaptureDevice) {
        continuityPrompt = nil
        captureCoordinator?.selectDevice(with: device.uniqueID)
    }

    func dismissContinuityPrompt() {
        continuityPrompt = nil
    }
    #endif
}

@available(iOS 14.0, *)
extension CameraKitViewModel: CameraKitCaptureCoordinatorDelegate {
    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didUpdate detection: CameraKitQuadrilateral?) {
        self.detection = detection
    }

    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didCapture image: UIImage, detection: CameraKitQuadrilateral?) {
        Task { @MainActor in
            self.isProcessing = false
            if configuration.mode == .realTime {
                let rect = liveCropRectForImage(imageSize: image.orientationAdjustedSize)
                let quad = CameraKitQuadrilateral.axisAligned(from: rect)
                self.process(image: image,
                             detection: nil,
                             manualRectangle: quad,
                             isFromLibrary: false)
            } else if shouldPresentManualCrop {
                let rect = detection?.boundingBox ?? CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                self.manualCropContext = ManualCropContext(image: image,
                                                           initialRect: rect,
                                                           detection: detection,
                                                           isFromLibrary: false)
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

#if canImport(PhotosUI)
@available(iOS 14.0, macCatalyst 14.0, *)
struct SystemImagePicker: UIViewControllerRepresentable {
    var selectionLimit: Int
    var onPick: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit <= 0 ? 0 : selectionLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: SystemImagePicker

        init(parent: SystemImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                picker.dismiss(animated: true) {
                    self.parent.onCancel()
                }
                return
            }

            let group = DispatchGroup()
            var images: [UIImage] = []

            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                picker.dismiss(animated: true) {
                    if images.isEmpty {
                        self.parent.onCancel()
                    } else {
                        self.parent.onPick(images)
                    }
                }
            }
        }
    }
}
#endif

struct SystemFilePicker: UIViewControllerRepresentable {
    var allowsMultipleSelection: Bool
    var onPick: ([URL]) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        if #available(iOS 14.0, macCatalyst 14.0, *) {
            #if canImport(UniformTypeIdentifiers)
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.image], asCopy: true)
            picker.delegate = context.coordinator
            picker.allowsMultipleSelection = allowsMultipleSelection
            return picker
            #else
            let picker = UIDocumentPickerViewController(documentTypes: ["public.image"], in: .import)
            picker.delegate = context.coordinator
            picker.allowsMultipleSelection = allowsMultipleSelection
            return picker
            #endif
        } else {
            #if canImport(MobileCoreServices)
            let legacyType = kUTTypeImage as String
            #else
            let legacyType = "public.image"
            #endif
            let picker = UIDocumentPickerViewController(documentTypes: [legacyType], in: .import)
            picker.delegate = context.coordinator
            picker.allowsMultipleSelection = allowsMultipleSelection
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: SystemFilePicker

        init(parent: SystemFilePicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
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

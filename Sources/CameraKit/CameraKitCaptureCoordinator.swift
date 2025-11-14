#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import AVFoundation
import UIKit
import Vision

@available(iOS 14.0, *)
@MainActor protocol CameraKitCaptureCoordinatorDelegate: AnyObject {
    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didUpdate detection: CameraKitQuadrilateral?)
    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didCapture image: UIImage, detection: CameraKitQuadrilateral?)
    func captureCoordinator(_ coordinator: CameraKitCaptureCoordinator, didFail error: CameraKitError)
}

@available(iOS 14.0, *)
final class CameraKitCaptureCoordinator: NSObject, ObservableObject {
    enum CaptureState {
        case idle
        case running
    }

    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.camerakit.session")
    private let detectionQueue = DispatchQueue(label: "com.camerakit.detection")
    private let stateQueue = DispatchQueue(label: "com.camerakit.state", attributes: .concurrent)
    private var latestDetectionStorage: CameraKitQuadrilateral?
    private var isPerformingDetectionStorage = false
    private var isSessionConfigured = false
    private var currentFlashMode: CameraKitFlashMode
    private var preferredDeviceID: String?
    private(set) var cameraPosition: AVCaptureDevice.Position = .back
    private let configuration: CameraKitConfiguration
    weak var delegate: CameraKitCaptureCoordinatorDelegate?

    init(configuration: CameraKitConfiguration) {
        self.configuration = configuration
        self.currentFlashMode = configuration.defaultFlashMode
        super.init()
    }

    func setFlashMode(_ mode: CameraKitFlashMode) {
        currentFlashMode = mode
    }

    func startSession() {
        CameraKitCaptureCoordinator.requestCameraAccessIfNeeded { [weak self] authorized in
            guard let self else { return }
            guard authorized else {
                self.notifyPermissionDenied()
                return
            }

            self.sessionQueue.async { [weak self] in
                guard let self else { return }
                if !self.isSessionConfigured {
                    do {
                        try self.configureSession()
                        self.isSessionConfigured = true
                    } catch {
                        self.notifyCameraUnavailable()
                        return
                    }
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(.auto), self.currentFlashMode == .auto {
                settings.flashMode = .auto
            } else if self.photoOutput.supportedFlashModes.contains(.on), self.currentFlashMode == .on {
                settings.flashMode = .on
            } else if self.photoOutput.supportedFlashModes.contains(.off) {
                settings.flashMode = .off
            }
            settings.isHighResolutionPhotoEnabled = true
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.preferredDeviceID = nil
            let newPosition: AVCaptureDevice.Position = self.cameraPosition == .back ? .front : .back
            guard let device = self.device(for: newPosition) else { return }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                if let currentInput = self.videoDeviceInput {
                    self.session.removeInput(currentInput)
                }
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoDeviceInput = input
                    self.cameraPosition = newPosition
                    self.latestDetectionValue = nil
                    self.dispatchToMain { [weak self] in
                        guard let self else { return }
                        self.delegate?.captureCoordinator(self, didUpdate: nil)
                    }
                }
                self.session.commitConfiguration()
            } catch {
                self.notifyCameraUnavailable()
            }
        }
    }

    func selectDevice(with uniqueID: String) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.preferredDeviceID = uniqueID
            self.reconfigureSessionForPreferredDevice()
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = preferredDeviceID.flatMap({ AVCaptureDevice(uniqueID: $0) }) ?? device(for: cameraPosition) else { throw CameraError.missingDevice }
        let videoInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(videoInput) else { throw CameraError.configurationFailed }
        session.addInput(videoInput)
        videoDeviceInput = videoInput

        guard session.canAddOutput(photoOutput) else { throw CameraError.configurationFailed }
        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true

        if configuration.enableLiveDetectionOverlay
            || configuration.mode == .scanSingle
            || configuration.mode == .scanBatch {
            videoDataOutput.setSampleBufferDelegate(self, queue: detectionQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                if let connection = videoDataOutput.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }

        session.commitConfiguration()
    }

    private func reconfigureSessionForPreferredDevice() {
        guard let preferredDeviceID,
              let device = AVCaptureDevice(uniqueID: preferredDeviceID) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if let currentInput = videoDeviceInput {
                session.removeInput(currentInput)
            }
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
                cameraPosition = device.position
                latestDetectionValue = nil
                dispatchToMain { [weak self] in
                    guard let self else { return }
                    self.delegate?.captureCoordinator(self, didUpdate: nil)
                }
            }
            session.commitConfiguration()
        } catch {
            notifyCameraUnavailable()
        }
    }

    private func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera,
            .builtInUltraWideCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: position)
        return discovery.devices.first
    }

    private var latestDetectionValue: CameraKitQuadrilateral? {
        get { stateQueue.sync { latestDetectionStorage } }
        set { stateQueue.sync(flags: .barrier) { self.latestDetectionStorage = newValue } }
    }

    private var isPerformingDetectionValue: Bool {
        get { stateQueue.sync { isPerformingDetectionStorage } }
        set { stateQueue.sync(flags: .barrier) { self.isPerformingDetectionStorage = newValue } }
    }

    private func notifyPermissionDenied() {
        dispatchToMain { [weak self] in
            guard let self else { return }
            self.delegate?.captureCoordinator(self, didFail: .permissionDenied)
        }
    }

    private func notifyCameraUnavailable() {
        dispatchToMain { [weak self] in
            guard let self else { return }
            self.delegate?.captureCoordinator(self, didFail: .cameraUnavailable)
        }
    }

    private func dispatchToMain(_ block: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            block()
        }
    }

    private static func requestCameraAccessIfNeeded(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
}

@available(iOS 14.0, *)
extension CameraKitCaptureCoordinator: @unchecked Sendable {}

private enum CameraError: Error {
    case missingDevice
    case configurationFailed
}

@available(iOS 14.0, *)
extension CameraKitCaptureCoordinator: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            dispatchToMain { [weak self] in
                guard let self else { return }
                self.delegate?.captureCoordinator(self, didFail: .captureFailed(reason: error.localizedDescription))
            }
            return
        }

        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            dispatchToMain { [weak self] in
                guard let self else { return }
                self.delegate?.captureCoordinator(self, didFail: .captureFailed(reason: "nil-data"))
            }
            return
        }

        dispatchToMain { [weak self] in
            guard let self else { return }
            let detection = self.latestDetectionValue
            self.delegate?.captureCoordinator(self, didCapture: image, detection: detection)
        }
    }
}

@available(iOS 14.0, *)
extension CameraKitCaptureCoordinator: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard configuration.enableLiveDetectionOverlay
                || configuration.mode == .scanSingle
                || configuration.mode == .scanBatch else { return }
        guard !isPerformingDetectionValue else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isPerformingDetectionValue = true
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self else { return }
            defer { self.isPerformingDetectionValue = false }
            if let error {
                self.dispatchToMain { [weak self] in
                    guard let self else { return }
                    self.delegate?.captureCoordinator(self, didFail: .captureFailed(reason: error.localizedDescription))
                }
                return
            }

            guard let observation = request.results?.first as? VNRectangleObservation else {
                self.dispatchToMain { [weak self] in
                    guard let self else { return }
                    self.latestDetectionValue = nil
                    self.delegate?.captureCoordinator(self, didUpdate: nil)
                }
                return
            }

            let quad = CameraKitQuadrilateral(
                topLeft: observation.topLeft.convertedToTopLeftCoordinateSpace(),
                topRight: observation.topRight.convertedToTopLeftCoordinateSpace(),
                bottomRight: observation.bottomRight.convertedToTopLeftCoordinateSpace(),
                bottomLeft: observation.bottomLeft.convertedToTopLeftCoordinateSpace()
            )

            self.dispatchToMain { [weak self] in
                guard let self else { return }
                self.latestDetectionValue = quad
                self.delegate?.captureCoordinator(self, didUpdate: quad)
            }
        }

        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.3

        let orientation: CGImagePropertyOrientation = .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            isPerformingDetectionValue = false
        }
    }
}

private extension CGPoint {
    func convertedToTopLeftCoordinateSpace() -> CGPoint {
        CGPoint(x: x, y: 1 - y)
    }
}
#endif

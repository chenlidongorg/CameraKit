#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import CoreImage
import SwiftUI
import UIKit

struct CameraKitProcessingPipeline {
    private let context = CIContext()
    let configuration: CameraKitConfiguration

    func process(image: UIImage,
                 detection: CameraKitQuadrilateral?,
                 manualRectangle: CameraKitQuadrilateral?,
                 isFromLibrary: Bool) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try performProcessing(image: image,
                                                       detection: detection,
                                                       manualRectangle: manualRectangle,
                                                       isFromLibrary: isFromLibrary)
                    continuation.resume(returning: result)
                } catch {
                    if let kitError = error as? CameraKitError {
                        continuation.resume(throwing: kitError)
                    } else {
                        continuation.resume(throwing: CameraKitError.processingFailed)
                    }
                }
            }
        }
    }

    private func performProcessing(image: UIImage,
                                   detection: CameraKitQuadrilateral?,
                                   manualRectangle: CameraKitQuadrilateral?,
                                   isFromLibrary _: Bool) throws -> UIImage {
        var workingImage = image.fixOrientation()

        let appliedCropSource = manualRectangle ?? detection
        let isScanMode = (configuration.mode == .scanSingle || configuration.mode == .scanBatch)

        if isScanMode, let quad = appliedCropSource {
            if let corrected = PerspectiveCorrector.correct(image: workingImage,
                                                            quadrilateral: quad,
                                                            context: context) {
                workingImage = corrected
            }
        } else if let manual = manualRectangle {
            if let cropped = AxisCropper.crop(image: workingImage, quadrilateral: manual) {
                workingImage = cropped
            }
        } else if configuration.allowsPostCaptureCropping, let manual = detection {
            if let cropped = AxisCropper.crop(image: workingImage, quadrilateral: manual) {
                workingImage = cropped
            }
        }

        if configuration.enhancement != .none,
           let enhanced = Enhancer.apply(configuration.enhancement, to: workingImage, context: context) {
            workingImage = enhanced
        }

        if let maxWidth = configuration.outputQuality.maxOutputWidth, maxWidth > 0 {
            let ratio = maxWidth / max(workingImage.size.width, 1)
            if ratio < 1 {
                let target = CGSize(width: maxWidth, height: workingImage.size.height * ratio)
                workingImage = workingImage.scaled(toFit: target)
            }
        } else if let target = configuration.outputQuality.targetResolution {
            workingImage = workingImage.scaled(toFit: target)
        }

        return workingImage
    }
}

private enum PerspectiveCorrector {
    static func correct(image: UIImage,
                        quadrilateral: CameraKitQuadrilateral,
                        context: CIContext) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent

        let points = quadrilateral.toCIPoints(size: extent.size)
        guard points.count == 4 else { return nil }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(points[0], forKey: "inputTopLeft")
        filter.setValue(points[1], forKey: "inputTopRight")
        filter.setValue(points[2], forKey: "inputBottomRight")
        filter.setValue(points[3], forKey: "inputBottomLeft")

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}

private enum AxisCropper {
    static func crop(image: UIImage, quadrilateral: CameraKitQuadrilateral) -> UIImage? {
        let rect = quadrilateral.boundingBox
        guard rect.width > 0, rect.height > 0 else { return nil }
        let cgRect = rect.pixelRect(imageSize: image.size)
        guard let cgImage = image.cgImage?.cropping(to: cgRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

private enum Enhancer {
    static func apply(_ enhancement: CameraKitEnhancement,
                      to image: UIImage,
                      context: CIContext) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let output: CIImage?
        switch enhancement {
        case .none:
            return image
        case .auto:
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(1.05, forKey: kCIInputSaturationKey)
            filter?.setValue(0.2, forKey: kCIInputBrightnessKey)
            filter?.setValue(1.1, forKey: kCIInputContrastKey)
            output = filter?.outputImage
        case .grayscale:
            let filter = CIFilter(name: "CIPhotoEffectMono")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            output = filter?.outputImage
        }

        guard let resolved = output,
              let cgImage = context.createCGImage(resolved, from: resolved.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

private extension CGRect {
    func pixelRect(imageSize: CGSize) -> CGRect {
        let width = self.width * imageSize.width
        let height = self.height * imageSize.height
        let x = origin.x * imageSize.width
        let y = (1 - (origin.y + self.height)) * imageSize.height
        let clampedWidth = min(width, imageSize.width - x)
        let clampedHeight = min(height, imageSize.height - max(0, y))
        return CGRect(x: max(0, x), y: max(0, y), width: max(1, clampedWidth), height: max(1, clampedHeight))
    }
}

private extension CameraKitQuadrilateral {
    func toCIPoints(size: CGSize) -> [CIVector] {
        [topLeft, topRight, bottomRight, bottomLeft].map { point in
            let converted = CGPoint(x: point.x * size.width,
                                    y: (1 - point.y) * size.height)
            return CIVector(x: converted.x, y: converted.y)
        }
    }
}
#endif

#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import SwiftUI
import UIKit

struct CameraKitCropView: View {
    let image: UIImage
    @State private var cropRect: CGRect
    let onCancel: () -> Void
    let onConfirm: (CGRect) -> Void

    init(image: UIImage,
         initialRect: CGRect,
         onCancel: @escaping () -> Void,
         onConfirm: @escaping (CGRect) -> Void) {
        self.image = image
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        let sanitized = initialRect.standardized.clampedRect()
        _cropRect = State(initialValue: sanitized.isEmpty ? CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9) : sanitized)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(CameraKitLocalization.string("camera_kit_crop_title"))
                .font(.headline)

            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    CropOverlayView(cropRect: $cropRect)
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Button(CameraKitLocalization.string("camera_kit_crop_reset")) {
                    withAnimation {
                        cropRect = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
                    }
                }
                Spacer()
                Button(CameraKitLocalization.string("camera_kit_cancel"), action: onCancel)
                Button(CameraKitLocalization.string("camera_kit_crop_done")) {
                    onConfirm(cropRect.clampedRect())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

private struct CropOverlayView: View {
    @Binding var cropRect: CGRect

    var body: some View {
        GeometryReader { geometry in
            let rect = cropRect.denormalized(in: geometry.size)
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addRect(rect)
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            ForEach(CropHandle.allCases, id: \.self) { handle in
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .position(handle.position(for: rect))
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let deltaX = value.translation.width / geometry.size.width
                            let deltaY = value.translation.height / geometry.size.height
                            cropRect = handle.update(rect: cropRect, delta: CGSize(width: deltaX, height: deltaY)).clampedRect()
                        })
            }
        }
    }
}

private enum CropHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    func position(for rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    func update(rect: CGRect, delta: CGSize) -> CGRect {
        var newRect = rect
        switch self {
        case .topLeft:
            newRect.origin.x += delta.width
            newRect.origin.y += delta.height
            newRect.size.width -= delta.width
            newRect.size.height -= delta.height
        case .topRight:
            newRect.origin.y += delta.height
            newRect.size.width += delta.width
            newRect.size.height -= delta.height
        case .bottomLeft:
            newRect.origin.x += delta.width
            newRect.size.width -= delta.width
            newRect.size.height += delta.height
        case .bottomRight:
            newRect.size.width += delta.width
            newRect.size.height += delta.height
        }
        return newRect
    }
}

private extension CGRect {
    func denormalized(in size: CGSize) -> CGRect {
        CGRect(x: origin.x * size.width,
               y: origin.y * size.height,
               width: width * size.width,
               height: height * size.height)
    }

    func translated(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: width, height: height)
    }

    func clampedRect() -> CGRect {
        var updated = self
        let minSize: CGFloat = 0.05
        updated.origin.x = min(max(0, updated.origin.x), 1 - minSize)
        updated.origin.y = min(max(0, updated.origin.y), 1 - minSize)
        updated.size.width = min(1 - updated.origin.x, max(minSize, updated.size.width))
        updated.size.height = min(1 - updated.origin.y, max(minSize, updated.size.height))
        return updated
    }
}
#endif


#Preview {
    
    CameraKitLauncherButton(
        configuration: CameraKitConfiguration(
            mode: .scan,
            enableLiveDetectionOverlay: true,
            allowsPostCaptureCropping: true,
            enhancement: .auto,
            allowsPhotoLibraryImport: true,
            outputQuality: .init(targetResolution: CGSize(width: 2000, height: 2000),
                                 compressionQuality: 0.8,
                                 returnOriginalImage: true),
            context: CameraKitContext(identifier: "invoice", payload: ["source": "home"])
        ),
        onResult: { result in
            // Handle processed image + metadata
        },
        onCancel: {
            // User dismissed the camera
        },
        onError: { error in
            // Present error message
        }
    )
    
}

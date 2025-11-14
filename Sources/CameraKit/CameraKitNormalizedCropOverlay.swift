#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import SwiftUI

@available(iOS 14.0, *)
struct CameraKitNormalizedCropOverlay: View {
    @Binding var cropRect: CGRect
    var dimmingColor: Color = .black.opacity(0.45)
    var strokeColor: Color = .white
    var handleColor: Color = .white
    var onGeometryChange: ((CGSize) -> Void)? = nil
    @State private var activeHandle: CameraKitCropHandle?
    @State private var initialRect: CGRect?

    var body: some View {
        GeometryReader { geometry in
            let rect = cropRect.denormalized(in: geometry.size)
            ZStack {
                if let handler = onGeometryChange {
                    Color.clear
                        .allowsHitTesting(false)
                        .onAppear { handler(geometry.size) }
                        .onChange(of: geometry.size) { newSize in
                            handler(newSize)
                        }
                }

                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRect(rect)
                }
                .fill(dimmingColor, style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: 2)
                    .stroke(strokeColor, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                ForEach(CameraKitCropHandle.allCases, id: \.self) { handle in
                    Circle()
                        .fill(handleColor)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .position(handle.position(for: rect))
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if activeHandle != handle {
                                    activeHandle = handle
                                    initialRect = cropRect
                                }
                                guard let startingRect = initialRect else { return }
                                let deltaX = value.translation.width / geometry.size.width
                                let deltaY = value.translation.height / geometry.size.height
                                cropRect = handle
                                    .update(rect: startingRect,
                                            delta: CGSize(width: deltaX, height: deltaY))
                                    .clampedRect()
                            }
                            .onEnded { _ in
                                activeHandle = nil
                                initialRect = nil
                            })
                }
            }
        }
    }
}

enum CameraKitCropHandle: CaseIterable {
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

extension CGRect {
    func denormalized(in size: CGSize) -> CGRect {
        CGRect(x: origin.x * size.width,
               y: origin.y * size.height,
               width: width * size.width,
               height: height * size.height)
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

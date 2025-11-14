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

                    CameraKitNormalizedCropOverlay(cropRect: $cropRect)
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
#endif


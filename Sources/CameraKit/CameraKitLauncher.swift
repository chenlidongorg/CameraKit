import SwiftUI

#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import UIKit


@available(iOS 14.0, *)
public struct CameraKitLauncher<Label: View>: View {
    @State private var isPresenting = false
    private let configuration: CameraKitConfiguration
    private let onResult: (CameraKitResult) -> Void
    private let onCancel: () -> Void
    private let onError: (CameraKitError) -> Void
    private let label: () -> Label

    public init(configuration: CameraKitConfiguration,
                onResult: @escaping (CameraKitResult) -> Void,
                onCancel: @escaping () -> Void = {},
                onError: @escaping (CameraKitError) -> Void,
                @ViewBuilder label: @escaping () -> Label) {
        self.configuration = configuration
        self.onResult = onResult
        self.onCancel = onCancel
        self.onError = onError
        self.label = label
    }

    public var body: some View {
        Button(action: { isPresenting = true }) {
            label()
        }
        .cameraKitFullScreenCover(isPresented: $isPresenting) {
            CameraKitExperienceView(configuration: configuration) { result in
                isPresenting = false
                onResult(result)
            } onCancel: {
                isPresenting = false
                onCancel()
            } onError: { error in
                isPresenting = false
                onError(error)
            }
        }
    }
}

@available(iOS 14.0, *)
public struct CameraKitLauncherButton: View {
    private let configuration: CameraKitConfiguration
    private let onResult: (CameraKitResult) -> Void
    private let onCancel: () -> Void
    private let onError: (CameraKitError) -> Void

    public init(configuration: CameraKitConfiguration,
                onResult: @escaping (CameraKitResult) -> Void,
                onCancel: @escaping () -> Void = {},
                onError: @escaping (CameraKitError) -> Void) {
        self.configuration = configuration
        self.onResult = onResult
        self.onCancel = onCancel
        self.onError = onError
    }

    public var body: some View {
        CameraKitLauncher(configuration: configuration,
                          onResult: onResult,
                          onCancel: onCancel,
                          onError: onError) {
            CameraKitDefaultButton()
        }
    }
}

struct CameraKitDefaultButton: View {
    var body: some View {
        HStack {
            Image(systemName: "camera.fill")
            Text(CameraKitLocalization.string("camera_kit_default_button"))
                .bold()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
        .foregroundColor(.accentColor)
    }
}

@available(iOS 14.0, *)
private extension View {
    func cameraKitFullScreenCover<Content: View>(isPresented: Binding<Bool>,
                                                 @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(CameraKitFullScreenCoverModifier(isPresented: isPresented, presentedContent: content))
    }
}

@available(iOS 14.0, *)
private struct CameraKitFullScreenCoverModifier<PresentedContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let presentedContent: () -> PresentedContent

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 14.0, *) {
                content.fullScreenCover(isPresented: $isPresented, content: presentedContent)
            } else {
                content.background(LegacyFullScreenCover(isPresented: $isPresented, content: presentedContent))
            }
        }
    }
}

@available(iOS 14.0, *)
private struct LegacyFullScreenCover<PresentedContent: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> PresentedContent

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            if context.coordinator.hostingController == nil {
                let hosting = UIHostingController(rootView: content())
                hosting.modalPresentationStyle = .fullScreen
                hosting.view.backgroundColor = .clear
                uiViewController.present(hosting, animated: true)
                context.coordinator.hostingController = hosting
            } else {
                context.coordinator.hostingController?.rootView = content()
            }
        } else {
            if let hosting = context.coordinator.hostingController {
                hosting.dismiss(animated: true) {
                    context.coordinator.hostingController = nil
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hostingController: UIHostingController<PresentedContent>?
    }
}
#endif

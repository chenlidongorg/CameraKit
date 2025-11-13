#if canImport(UIKit) && (os(iOS) || targetEnvironment(macCatalyst))
import UIKit

extension UIImage {
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }

    func scaled(toFit target: CGSize) -> UIImage {
        guard target.width > 0, target.height > 0 else { return self }
        let aspectWidth = target.width / size.width
        let aspectHeight = target.height / size.height
        let ratio = min(aspectWidth, aspectHeight)
        if ratio >= 1 { return self }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif

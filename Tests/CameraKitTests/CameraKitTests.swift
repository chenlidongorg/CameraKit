import CoreGraphics
import Testing
@testable import CameraKit

@Test func configurationDefaults() throws {
    let config = CameraKitConfiguration()
    #expect(config.mode == .photo)
    #expect(config.enableLiveDetectionOverlay == true)
    #expect(config.enhancement == .none)
    #expect(config.outputQuality.compressionQuality == 0.85)
}

@Test func quadrilateralBoundingBox() throws {
    let quad = CameraKitQuadrilateral(
        topLeft: CGPoint(x: 0.1, y: 0.2),
        topRight: CGPoint(x: 0.9, y: 0.25),
        bottomRight: CGPoint(x: 0.95, y: 0.85),
        bottomLeft: CGPoint(x: 0.05, y: 0.9)
    )
    let rect = quad.boundingBox
    #expect(abs(rect.origin.x - 0.05) < 0.0001)
    #expect(abs(rect.origin.y - 0.2) < 0.0001)
    #expect(rect.width > 0.8)
    #expect(rect.height > 0.6)
}

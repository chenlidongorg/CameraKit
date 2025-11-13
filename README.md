# CameraKit

> EN · CameraKit is a SwiftUI-based shooting component that launches the full camera/scan/crop pipeline from an external trigger button, returning structured results via callbacks.
>
> 中文 · CameraKit 是一个 Swift/SwiftUI 实现的通用拍摄组件，由外部按钮触发，内部完成拍照、扫描、裁剪、增强等流程，并通过结构化回调返回结果。

## Features · 功能特性

- **Unified flow / 统一流程** – Camera permission handling, preview, capture, Vision-based scan, cropping, enhancement, exporting in one place.
- **Flexible entry / 灵活入口** – Provide your own SwiftUI label or use the built-in launcher button with localized strings (English/简体中文)。
- **Config driven / 配置驱动** – Toggle scan mode, live detection overlay, manual crop, enhancement, flash behavior, album import, output quality.
- **Structured callbacks / 结构化回调** – Receive processed + optional original image, detected & adjusted rectangles, enhancement metadata, custom context payloads, and typed errors or cancellation.
- **SPM ready / 支持 Swift Package Manager** – Minimum iOS 13 / macOS Catalyst 13, pure Swift Package with resources bundled via `Bundle.module`.

## Installation · 安装

Add the Git URL to your Package.swift dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/CameraKit.git", branch: "main")
]
```

and include the product where needed:

```swift
.product(name: "CameraKit", package: "CameraKit")
```

## Usage · 使用示例

```swift
import CameraKit

struct ScanActionView: View {
    var body: some View {
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
}
```

- Default UI is a full screen SwiftUI experience with cancel, flash, flip, shutter, Vision overlay and optional album import.
- Provide your own label by using `CameraKitLauncher` and a custom `label` closure.

## Configuration · 配置项

| Property / 属性 | Description / 说明 |
| --- | --- |
| `mode` | `.photo` returns the original frame; `.scan` performs rectangle detection +透视裁剪。 |
| `enableLiveDetectionOverlay` | Show live Vision detection overlay + guidance text. /
| `allowsPostCaptureCropping` | Present the built-in crop editor after capture for manual tweaks. /
| `enhancement` | `.none`, `.auto`, `.grayscale` 自动增强策略。 |
| `allowsPhotoLibraryImport` | Allow replacing the capture with an album photo. /
| `outputQuality` | Target resolution, JPEG compression, whether to return the original image. /
| `defaultFlashMode` | `.auto`, `.on`, `.off` – reflected in the UI chip. /
| `context` & `metadata` | Business identifiers echoed back inside `CameraKitResult`. |

## Callbacks · 回调

- `onResult` – returns `CameraKitResult` with:
  - `processedImage` / `originalImage?`
  - `detectedRectangle` (auto Vision result) & `adjustedRectangle` (manual crop)
  - `enhancement` applied, `metadata`, optional `context`, JPEG data snapshot.
- `onCancel` – invoked when the user dismisses the sheet.
- `onError` – typed `CameraKitError` (`permissionDenied`, `cameraUnavailable`, `captureFailed`, `processingFailed`).

## Localization · 国际化

- Default localization is **English** with Simplified Chinese resources under `Sources/CameraKit/Resources/`.
- All visible strings (button labels, helper text, alerts) go through `CameraKitLocalization.string(_:)`.
- To extend localization, add another `.lproj/Localizable.strings` inside the target and update values.

## Testing · 测试

```bash
swift test
```

(If sandboxing blocks SwiftPM cache access, rerun with the necessary permissions.)

## Requirements · 环境

- Swift 6 toolchain
- iOS 13 / macOS 14 (Catalyst 14) minimum
- AVFoundation + Vision access enabled in host app (`NSCameraUsageDescription` required)

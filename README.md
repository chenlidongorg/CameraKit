# CameraKit

CameraKit 是一个面向 Swift / SwiftUI 应用的拍摄与扫描组件，提供从权限请求、取景、拍摄、矩形识别、裁剪、增强到导出结果的一站式流程。开发者只需触发入口按钮并处理回调数据，即可获得自动矫正方向、可选等比缩放后的 `[UIImage]` 数组。

## 功能模块与可选性

| 模块 | 能力说明 | 是否可选 | 备注 |
| --- | --- | --- | --- |
| 相机权限 & 设备检查 | 自动请求 `NSCameraUsageDescription` 权限，并校验摄像头可用性。 | 否 | 必须同意权限才能进入拍摄界面。 |
| 实时预览与拍摄 | SwiftUI 全屏取景界面，包含闪光灯、切换摄像头、快门、取消按钮。 | 否 | 默认 UI 可直接使用，也可自定义触发入口。 |
| Vision 扫描识别 | 基于矩形检测的实时高亮与自动裁切建议。 | 是 | 通过 `mode` 或 `enableLiveDetectionOverlay` 关闭。 |
| 手动裁剪 | 拍摄后进入可拖拽四角的裁剪器。 | 是 | `allowsPostCaptureCropping` 控制。 |
| 图像增强 | 支持 `none` / `auto` / `grayscale` 等策略，提升可读性。 | 是 | 由 `enhancement` 配置。 |
| 相册导入 | 用户可从相册替换拍摄结果，适合补传文件。 | 是 | `allowsPhotoLibraryImport` 控制。 |
| 结果回调 | 将本次操作产生的所有图片以 `[UIImage]` 形式回传，已统一方向与尺寸。 | 否 | 单次实时/拍照仅返回 1 张，扫描/多选则按序返回多张。 |
| 国际化与文案 | 内建英文 + 简体中文，可拓展自定义语言。 | 是 | 添加新的 `.lproj` 资源即可。 |

## 配置项总览

| 配置项 | 作用 | 是否必填 | 默认值 / 建议 |
| --- | --- | --- | --- |
| `mode` | `.realTime`（拍前可拖拽取景框）、`.photo`（标准拍摄）、`.photoWithCrop`（拍后裁剪）、`.scanSingle` / `.scanBatch`（基于 `VNDocumentCamera` 的单/多页扫描）。 | 必填 | 根据场景选择合适模式，可随时切换。 |
| `defaultRealtimeHeight` | `.realTime` 模式下高亮取景框的默认高度（0-1 归一化比例）。 | 可选 | 默认 `0.8`，可按票据/文档纵横比预设，高度可再拖拽调整，宽度固定 `0.8`。 |
| `enableLiveDetectionOverlay` | 实时显示检测框和提示。 | 可选 | 默认 `true`，用于辅助取景，关闭后可减少轻微的 Vision 计算开销。 |
| `allowsPostCaptureCropping` | 是否在结果页弹出手动裁剪。 | 可选 | `.photoWithCrop` 模式默认开启，其余模式按需设置。 |
| `enhancement` | 输出增强策略：`.none` / `.auto` / `.grayscale`。 | 可选 | 默认 `.auto`。 |
| `allowsPhotoLibraryImport` | 是否允许从相册替换。 | 可选 | 默认 `false`。 |
| `outputQuality` | 控制分辨率、压缩率，以及 `targetResolution` / `maxOutputWidth` 等比缩放策略。 | 可选 | 默认压缩率 `0.85`，`targetResolution` / `maxOutputWidth` 默认为 `nil`：若设置 `maxOutputWidth`，最终宽度被限制在该值内，高度按比例缩放；若未设置宽度而提供 `targetResolution`，则会按“scale to fit”方式将图片缩小进指定盒子——即仅做等比缩放不会填充留白、不会裁切，示例：目标 300×600、原图 400×900 时，最终尺寸 ≈266×600。 |
| `defaultFlashMode` | `.auto` / `.on` / `.off`。 | 可选 | 默认 `.auto`，控制快门首次打开时的闪光灯行为。 |
| `context` | 业务侧上下文，在回调中回传。 | 可选 | 用于区分不同入口或携带额外数据。 |

> 小贴士：所有配置都通过 `CameraKitConfiguration` 构造体集中管理，便于在不同页面复用或根据业务动态调整。

- `enableLiveDetectionOverlay` 仅影响拍摄界面上是否画出实时检测矩形以及提示文案，与实时模式、扫描模式或裁剪模式均不冲突；若场景对性能极度敏感或希望界面简洁，可将其改为 `false`。
- `targetResolution` 与 `maxOutputWidth` 不会同时生效：当指定了 `maxOutputWidth` 时优先限制宽度，并按比例推导高度；只有在未提供 `maxOutputWidth` 时，才会按照 `targetResolution` 的宽高计算缩放，使输出图片完整地落在该尺寸边界之内（保持原始纵横比，不拉伸、不填充）。

## 回调数据

- `onResult([UIImage])`：返回按照选择顺序处理好的所有图片（已校正方向，可选缩放宽度）。
- `onOriginalImageResult?([UIImage])`：可选回调。若传入该闭包，则会额外收到“未处理”的原始图片数组（顺序与 `onResult` 一致）；未提供闭包时则默认不回传原图，避免不必要的内存与带宽开销。
- `onCancel()`：用户主动关闭或返回。
- `onError(CameraKitError)`：包含 `permissionDenied`、`cameraUnavailable`、`captureFailed`、`processingFailed` 等类型，便于友好提示。

## 安装方式（Swift Package Manager）

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/your-org/CameraKit.git", branch: "main")
]
```

并在目标中引入：

```swift
.product(name: "CameraKit", package: "CameraKit")
```

## 快速使用示例

```swift
import CameraKit

struct ScanActionView: View {
    var body: some View {
        CameraKitLauncherButton(
            configuration: CameraKitConfiguration(
                mode: .scanBatch,
                enableLiveDetectionOverlay: true,
                allowsPostCaptureCropping: false,
                enhancement: .auto,
                allowsPhotoLibraryImport: true,
                outputQuality: .init(
                    targetResolution: nil,
                    compressionQuality: 0.85,
                    maxOutputWidth: 2048
                ),
                context: CameraKitContext(identifier: "invoice", payload: ["source": "首页入口"])
            ),
            onResult: { images in
                // 处理扫描结果，images 为自动矫正后的数组
            },
            onOriginalImageResult: { originals in
                // 如需保存/另行处理原图，在这里拿到同顺序的原始数组
            },
            onCancel: {
                // 关闭或返回后的兜底逻辑
            },
            onError: { error in
                // 根据 CameraKitError 展示提示
            }
        )
    }
}
```

若需要自定义按钮外观，可直接使用 `CameraKitLauncher` 并传入自定义 `label` 视图。

## 国际化

- 默认提供英文与简体中文资源，位于 `Sources/CameraKit/Resources/`。
- 若需扩展语言，在目标内新增相应 `.lproj/Localizable.strings` 并添加翻译，同时保持键值不变。

## 运行要求与权限

- Swift 6 工具链。
- iOS 13+ 或 macOS Catalyst 13+。
- 在宿主 App 的 `Info.plist` 中添加 `NSCameraUsageDescription`；若启用相册导入，再增加 `NSPhotoLibraryUsageDescription`。
- 需在 App 启动前确保已获取 Vision / AVFoundation 所需的权限声明。

## 测试

```bash
swift test
```

若在沙箱环境中拉取依赖失败，请根据提示授权或在本地再次执行。

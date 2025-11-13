# CameraKit

CameraKit 是一个面向 Swift / SwiftUI 应用的拍摄与扫描组件，提供从权限请求、取景、拍摄、矩形识别、裁剪、增强到导出结果的一站式流程。开发者只需触发入口按钮并处理回调数据，即可获得结构化的扫描结果和元数据。

## 功能模块与可选性

| 模块 | 能力说明 | 是否可选 | 备注 |
| --- | --- | --- | --- |
| 相机权限 & 设备检查 | 自动请求 `NSCameraUsageDescription` 权限，并校验摄像头可用性。 | 否 | 必须同意权限才能进入拍摄界面。 |
| 实时预览与拍摄 | SwiftUI 全屏取景界面，包含闪光灯、切换摄像头、快门、取消按钮。 | 否 | 默认 UI 可直接使用，也可自定义触发入口。 |
| Vision 扫描识别 | 基于矩形检测的实时高亮与自动裁切建议。 | 是 | 通过 `mode` 或 `enableLiveDetectionOverlay` 关闭。 |
| 手动裁剪 | 拍摄后进入可拖拽四角的裁剪器。 | 是 | `allowsPostCaptureCropping` 控制。 |
| 图像增强 | 支持 `none` / `auto` / `grayscale` 等策略，提升可读性。 | 是 | 由 `enhancement` 配置。 |
| 相册导入 | 用户可从相册替换拍摄结果，适合补传文件。 | 是 | `allowsPhotoLibraryImport` 控制。 |
| 结果回调 & 元数据 | 返回处理后图像、原图、检测矩形、业务上下文、错误信息。 | 否 | 所有流程的输出入口。 |
| 国际化与文案 | 内建英文 + 简体中文，可拓展自定义语言。 | 是 | 添加新的 `.lproj` 资源即可。 |

## 配置项总览

| 配置项 | 作用 | 是否必填 | 默认值 / 建议 |
| --- | --- | --- | --- |
| `mode` | `.photo`（仅拍摄）或 `.scan`（包含检测与裁剪）。 | 必填 | `.scan` 更适合文档扫描。 |
| `enableLiveDetectionOverlay` | 实时显示检测框和提示。 | 可选 | 默认 `true`，拍照模式可设为 `false`。 |
| `allowsPostCaptureCropping` | 是否在结果页弹出手动裁剪。 | 可选 | 默认 `true`。 |
| `enhancement` | 输出增强策略：`.none` / `.auto` / `.grayscale`。 | 可选 | 默认 `.auto`。 |
| `allowsPhotoLibraryImport` | 是否允许从相册替换。 | 可选 | 默认 `false`。 |
| `outputQuality` | 控制分辨率、压缩率、是否回传原图。 | 可选 | 默认压缩率 `0.85`，`targetResolution` 默认为 `nil`（不缩放），可按需指定。 |
| `defaultFlashMode` | `.auto` / `.on` / `.off`。 | 可选 | 默认 `.auto`。 |
| `context` | 业务侧上下文，在回调中回传。 | 可选 | 用于区分不同入口或携带额外数据。 |

> 小贴士：所有配置都通过 `CameraKitConfiguration` 构造体集中管理，便于在不同页面复用或根据业务动态调整。

## 回调数据

- `onResult(CameraKitResult)`：返回处理后图片 `processedImage`、可选原图 `originalImage`、`detectedRectangle`、`adjustedRectangle`、`enhancement`、`metadata` 以及自定义 `context`。
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
                mode: .scan,
                enableLiveDetectionOverlay: true,
                allowsPostCaptureCropping: true,
                enhancement: .auto,
                allowsPhotoLibraryImport: true,
                outputQuality: .init(
                    targetResolution: CGSize(width: 2000, height: 2000),
                    compressionQuality: 0.8,
                    returnOriginalImage: true
                ),
                context: CameraKitContext(identifier: "invoice", payload: ["source": "首页入口"])
            ),
            onResult: { result in
                // 处理扫描结果、坐标信息与业务上下文
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

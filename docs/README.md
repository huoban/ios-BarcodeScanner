# 条码扫描记录（iOS 版）

从 [Android-BarcodeScanner](https://github.com/huoban/Android-BarcodeScanner) 移植到 iOS 的条码扫描与记录工具。仅面向 iPhone 的 iOS 15（最高 15.8.7），部署目标 iOS 15.0，不考虑向下兼容。

## 原生替代方案

| Android 依赖 | iOS 15 原生替代 |
|---|---|
| CameraX 预览 + ImageAnalysis | `AVCaptureSession` + `AVCaptureVideoPreviewLayer` |
| Google ML Kit Barcode Scanning | `AVCaptureMetadataOutput`（原生 13 种条码格式） |
| Room | Core Data（代码构造模型，无 `.xcdatamodeld`） |
| SharedPreferences | `UserDefaults` |
| AudioTrack 合成提示音 | `AVAudioEngine` + `AVAudioPCMBuffer` |
| WebP 图片保存 | ImageIO/JPEG（compressionQuality 0.8） |
| OkHttp | `URLSession` |
| WebView | `WKWebView` |
| FileProvider 分享 | `UIActivityViewController` |

## 功能

- 全屏相机预览，76mm × 130mm 取景框（按 160pt/inch 换算，最大不超过屏幕 80%）
- 连续 2 帧结果一致才确认；拒绝含控制字符的条码内容
- 支持 13 种格式：QR、Data Matrix、PDF417、Code 128、Code 39、Code 93、Codabar、EAN-13、EAN-8、UPC-A、UPC-E、ITF、Aztec
- 扫描方向（水平 ±20° / 全方向）、扫描分辨率（720p / 1080p）、字符串编码设置
- 前置摄像头、闪光灯、最小/最大变焦切换
- 提示音（频率/时长/调制/音量）、振动、自动复制、自动提交
- 自动提交地址 `{result}` 占位符替换（百分号编码），内置 `WKWebView`
- 扫码成功保存 JPEG 截图（应用私有目录）
- 历史记录：本地模糊搜索、远程查询（3 秒防抖、蓝色展示）、截图预览（缩放/双击）、CSV 导出
- 删除 15/30/60/90/180 天前或清空全部，二次确认，截图同步删除
- 设置页含全部开关与关于页

## 构建 IPA

### GitHub Actions（推荐）

仓库包含 `.github/workflows/build.yml`，推送 `main` 或手动触发 `workflow_dispatch` 后在 macOS Runner 上构建，IPA 作为 Artifact 上传，路径为 `code/build/BarcodeScanner.ipa`。

### 本地 macOS

```bash
brew install xcodegen
cd code
xcodegen generate --spec project.yml --project BarcodeScanner.xcodeproj
bash scripts/build_ipa.sh
```

产物：`code/build/BarcodeScanner.ipa`。

### 签名

默认构建为未签名 IPA（便于 CI 产出）。若需安装到真机，需要 Apple Developer 证书与对应 Provisioning Profile。设置环境变量 `SIGNING_IDENTITY`、`PROVISIONING_PROFILE_SPECIFIER` 即可启用签名；GitHub Actions 可通过 Secrets 注入：

- `SIGNING_P12_BASE64`、`SIGNING_P12_PASSWORD`、`SIGNING_PROFILE_BASE64`、`KEYCHAIN_PASSWORD`
- `SIGNING_IDENTITY`、`PROVISIONING_PROFILE_SPECIFIER`

## 已知限制

- iOS 原生 API 只提供解码后的字符串，不暴露条码原始字节；字符串编码设置对 UTF-8 字节做最佳-effort 重解码，不能像 Android 那样直接解码 GBK/ISO-8859-1 原始字节。
- 默认产出未签名 IPA，需签名后才能安装到真机。
- GS1 标记按解码字符串前缀 `]e0` 判断，与 Android 行为一致（Android 基于 ML Kit rawValue）。

项目地址：<https://github.com/huoban/ios-BarcodeScanner>

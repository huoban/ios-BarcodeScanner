import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        Form {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                    Text("条码扫描记录")
                        .font(.headline)
                }
                Spacer()
            }
            Section {
                Text("应用版本: \(version)")
                Text("扫码引擎: iOS 原生 AVFoundation")
                Text("基于 AVFoundation 原生扫码能力构建\n支持 13 种常用条码格式识别")
                    .font(.footnote)
            }
            Section {
                Link("项目地址", destination: URL(string: "https://github.com/huoban/ios-BarcodeScanner")!)
            }
        }
        .navigationTitle("关于")
    }
}

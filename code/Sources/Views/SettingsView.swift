import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section("条码格式") {
                    ForEach(BarcodeFormat.allCases) { format in
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle(format.title, isOn: Binding(
                                get: { format.isEnabled(in: self.preferences) },
                                set: { format.setEnabled($0, in: self.preferences) }
                            ))
                            Text(format.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("相机") {
                    Toggle("前置摄像头", isOn: binding(for: \.useFrontCamera))
                    Picker("扫描方向", selection: binding(for: \.scanOrientation)) {
                        Text("水平").tag("Horizontal")
                        Text("全方向").tag("Omni")
                    }
                    Picker("扫描分辨率", selection: binding(for: \.scanningResolution)) {
                        Text("HD (720p)").tag("HD")
                        Text("Full HD (1080p)").tag("FullHD")
                    }
                    Picker("字符串编码", selection: binding(for: \.stringEncoding)) {
                        Text("UTF-8").tag("UTF-8")
                        Text("ISO-8859-1").tag("ISO-8859-1")
                        Text("GBK").tag("GBK")
                    }
                }

                Section("提示") {
                    Toggle("扫码提示音", isOn: binding(for: \.soundEnabled))
                    labelledNumber("频率 (Hz)", value: binding(for: \.soundFrequency))
                    labelledNumber("时长 (ms)", value: binding(for: \.soundLength))
                    labelledNumber("调制", value: binding(for: \.soundModulation))
                    labelledNumber("音量 (%)", value: binding(for: \.soundVolume))
                    Toggle("振动", isOn: binding(for: \.vibrateEnabled))
                }

                Section("结果处理") {
                    Toggle("自动复制到剪贴板", isOn: binding(for: \.autoCopyToClipboard))
                    Toggle("自动提交", isOn: binding(for: \.openURLAutomatically))
                    TextField("https://example.com/api?code={result}", text: binding(for: \.webhookURL))
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section("历史记录") {
                    Toggle("远程查询", isOn: binding(for: \.remoteQueryEnabled))
                    TextField("https://example.com/api?cxid=", text: binding(for: \.remoteQueryURL))
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section {
                    NavigationLink("关于", destination: AboutView())
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { self.presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func binding<T>(for keyPath: ReferenceWritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(
            get: { self.preferences[keyPath: keyPath] },
            set: { self.preferences[keyPath: keyPath] = $0 }
        )
    }

    private func labelledNumber(_ title: String, value: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
    }
}

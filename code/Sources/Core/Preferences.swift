import Foundation

/// 与 Android SharedPreferences 同键名、同默认值的设置封装
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func flag(_ key: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    private func text(_ key: String, _ fallback: String) -> String {
        defaults.string(forKey: key) ?? fallback
    }

    private func setFlag(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
        objectWillChange.send()
    }

    private func setText(_ value: String, _ key: String) {
        defaults.set(value, forKey: key)
        objectWillChange.send()
    }

    var qrEnabled: Bool {
        get { flag("QR", false) }
        set { setFlag(newValue, "QR") }
    }
    var dataMatrixEnabled: Bool {
        get { flag("DataMatrix", false) }
        set { setFlag(newValue, "DataMatrix") }
    }
    var code39Enabled: Bool {
        get { flag("Code39", false) }
        set { setFlag(newValue, "Code39") }
    }
    var upceanEnabled: Bool {
        get { flag("UPCEAN", false) }
        set { setFlag(newValue, "UPCEAN") }
    }
    var code128Enabled: Bool {
        get { flag("Code128", true) }
        set { setFlag(newValue, "Code128") }
    }
    var pdfEnabled: Bool {
        get { flag("PDF", false) }
        set { setFlag(newValue, "PDF") }
    }
    var aztecEnabled: Bool {
        get { flag("Aztec", false) }
        set { setFlag(newValue, "Aztec") }
    }
    var code93Enabled: Bool {
        get { flag("Code93", false) }
        set { setFlag(newValue, "Code93") }
    }
    var code2of5Enabled: Bool {
        get { flag("Code2of5", false) }
        set { setFlag(newValue, "Code2of5") }
    }
    var codabarEnabled: Bool {
        get { flag("Codabar", false) }
        set { setFlag(newValue, "Codabar") }
    }

    /// Horizontal / Omni
    var scanOrientation: String {
        get { text("scanOrientations", "Omni") }
        set { setText(newValue, "scanOrientations") }
    }
    /// HD / FullHD
    var scanningResolution: String {
        get { text("scanningResolution", "FullHD") }
        set { setText(newValue, "scanningResolution") }
    }
    var useFrontCamera: Bool {
        get { flag("useFrontCamera", false) }
        set { setFlag(newValue, "useFrontCamera") }
    }
    var initialZoom: String {
        get { text("initialZoom", "0") }
        set { setText(newValue, "initialZoom") }
    }

    var soundEnabled: Bool {
        get { flag("notificationSoundEnabled", true) }
        set { setFlag(newValue, "notificationSoundEnabled") }
    }
    var soundFrequency: String {
        get { text("notificationSoundFrequencyValue", "1000") }
        set { setText(newValue, "notificationSoundFrequencyValue") }
    }
    var soundLength: String {
        get { text("notificationSoundLengthValue", "150") }
        set { setText(newValue, "notificationSoundLengthValue") }
    }
    var soundModulation: String {
        get { text("notificationSoundModulationValue", "0") }
        set { setText(newValue, "notificationSoundModulationValue") }
    }
    var soundVolume: String {
        get { text("notificationSoundVolumeValue", "80") }
        set { setText(newValue, "notificationSoundVolumeValue") }
    }
    var vibrateEnabled: Bool {
        get { flag("notificationVibrateEnabled", true) }
        set { setFlag(newValue, "notificationVibrateEnabled") }
    }

    var autoCopyToClipboard: Bool {
        get { flag("autoCopyToClipboard", false) }
        set { setFlag(newValue, "autoCopyToClipboard") }
    }
    var openURLAutomatically: Bool {
        get { flag("openUrlAutomatically", false) }
        set { setFlag(newValue, "openUrlAutomatically") }
    }
    var webhookURL: String {
        get { text("customWebhookUrl", "https://example.com/api?code={result}") }
        set { setText(newValue, "customWebhookUrl") }
    }
    var remoteQueryEnabled: Bool {
        get { flag("remoteQueryEnabled", false) }
        set { setFlag(newValue, "remoteQueryEnabled") }
    }
    var remoteQueryURL: String {
        get { text("remoteQueryUrl", "https://example.com/api?cxid=") }
        set { setText(newValue, "remoteQueryUrl") }
    }
    /// UTF-8 / ISO-8859-1 / GBK
    var stringEncoding: String {
        get { text("readStringEncoding", "UTF-8") }
        set { setText(newValue, "readStringEncoding") }
    }

    var isFirstLaunch: Bool {
        get { flag("is_first_launch", true) }
        set { setFlag(newValue, "is_first_launch") }
    }
}

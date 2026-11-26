import SwiftUI

@main
struct BarcodeScannerApp: App {
    @StateObject private var preferences = Preferences.shared
    @StateObject private var historyStore = HistoryStore.shared

    var body: some Scene {
        WindowGroup {
            ScannerView()
                .environmentObject(preferences)
                .environmentObject(historyStore)
                .accentColor(.purple)
        }
    }
}

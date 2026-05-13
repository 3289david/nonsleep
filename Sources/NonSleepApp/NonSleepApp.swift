import SwiftUI

@main
struct NonSleepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: appDelegate.isEnabled ? "moon.zzz.fill" : "moon.zzz")
                .symbolRenderingMode(.hierarchical)
        }

        Settings {
            SettingsView()
        }
    }
}

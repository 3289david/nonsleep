import SwiftUI

@main
struct NonSleepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appDelegate.isEnabled
                    ? "bolt.horizontal.circle.fill"
                    : "moon.zzz")
            }
        }

        Settings {
            SettingsView()
        }
    }
}

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        VStack(spacing: 0) {
            Button {
                appDelegate.toggle()
            } label: {
                HStack {
                    Image(systemName: appDelegate.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(appDelegate.isEnabled ? .green : .secondary)
                    Text("Disable Sleep")
                    Spacer()
                    Text(appDelegate.isEnabled ? "ON" : "OFF")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .keyboardShortcut("d")

            Divider()

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit NonSleep") {
                appDelegate.disable()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

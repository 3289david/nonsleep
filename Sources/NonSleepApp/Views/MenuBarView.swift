import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        Button {
            appDelegate.toggle()
        } label: {
            HStack {
                Image(systemName: appDelegate.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(appDelegate.isEnabled ? .green : .secondary)
                Text("Prevent Sleep")
                Spacer()
                Text(appDelegate.isEnabled ? "ON" : "OFF")
                    .foregroundStyle(appDelegate.isEnabled ? .green : .secondary)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }
        }
        .keyboardShortcut("d")

        Divider()

        Button("Quit") {
            appDelegate.disable()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

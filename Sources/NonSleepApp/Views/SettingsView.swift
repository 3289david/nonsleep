import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        TabView {
            Form {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            }
            .padding()
            .tabItem { Label("General", systemImage: "gear") }

            VStack(alignment: .leading, spacing: 12) {
                Text("NonSleep").font(.headline)
                Text("MIT License").font(.subheadline).foregroundStyle(.secondary)
                Text("Copyright (c) 2025 NonSleep Contributors")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 300, height: 120)
    }
}

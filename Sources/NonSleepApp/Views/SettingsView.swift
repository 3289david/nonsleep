import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("enableOnStartup") private var enableOnStartup = false
    @AppStorage("showNotifications") private var showNotifications = true

    var body: some View {
        TabView {
            GeneralSettingsView(
                launchAtLogin: $launchAtLogin,
                enableOnStartup: $enableOnStartup,
                showNotifications: $showNotifications
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            LegalView()
                .tabItem {
                    Label("Legal", systemImage: "doc.text")
                }
        }
        .frame(width: 360, height: 200)
    }
}

struct GeneralSettingsView: View {
    @Binding var launchAtLogin: Bool
    @Binding var enableOnStartup: Bool
    @Binding var showNotifications: Bool

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }

            Toggle("Enable on Startup", isOn: $enableOnStartup)
            Toggle("Show Notifications", isOn: $showNotifications)
        }
        .padding()
    }
}

struct LegalView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("NonSleep")
                    .font(.headline)

                Text("MIT License")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("""
                Copyright (c) 2025 NonSleep Contributors

                Permission is hereby granted, free of charge, to any person obtaining a copy \
                of this software and associated documentation files (the "Software"), to deal \
                in the Software without restriction, including without limitation the rights \
                to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                copies of the Software, and to permit persons to whom the Software is \
                furnished to do so, subject to the following conditions:

                The above copyright notice and this permission notice shall be included in all \
                copies or substantial portions of the Software.

                THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
                IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

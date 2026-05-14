import AppKit
import Foundation
import IOKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isEnabled: Bool = false

    private var systemAssertionID: IOPMAssertionID = 0
    private var idleAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion = false
    private var hasIdleAssertion = false
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureStateDir()
        loadState()
        syncAssertion()
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTimer?.invalidate()
        releaseAllAssertions()
    }

    // MARK: - Toggle

    func toggle() {
        isEnabled.toggle()
        saveState()
        syncAssertion()
    }

    func enable() {
        isEnabled = true
        saveState()
        syncAssertion()
    }

    func disable() {
        isEnabled = false
        saveState()
        syncAssertion()
    }

    // MARK: - Polling (reliable sync with CLI/daemon)

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkStateFile()
        }
    }

    private func checkStateFile() {
        let url = stateFileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else { return }

        if state.enabled != isEnabled {
            isEnabled = state.enabled
            syncAssertion()
        }
    }

    // MARK: - IOKit Power Assertions

    private func syncAssertion() {
        if isEnabled {
            createAssertions()
        } else {
            releaseAllAssertions()
        }
    }

    private func createAssertions() {
        if !hasSystemAssertion {
            let r1 = IOPMAssertionCreateWithName(
                "PreventSystemSleep" as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NonSleep: Preventing clamshell sleep" as CFString,
                &systemAssertionID
            )
            if r1 == kIOReturnSuccess { hasSystemAssertion = true }
        }

        if !hasIdleAssertion {
            let r2 = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NonSleep: Preventing idle sleep" as CFString,
                &idleAssertionID
            )
            if r2 == kIOReturnSuccess { hasIdleAssertion = true }
        }
    }

    private func releaseAllAssertions() {
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertionID)
            hasSystemAssertion = false
            systemAssertionID = 0
        }
        if hasIdleAssertion {
            IOPMAssertionRelease(idleAssertionID)
            hasIdleAssertion = false
            idleAssertionID = 0
        }
    }

    // MARK: - State File

    private func ensureStateDir() {
        let dir = stateFileURL().deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func loadState() {
        let url = stateFileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            isEnabled = false
            return
        }
        isEnabled = state.enabled
    }

    private func saveState() {
        let state = AppState(enabled: isEnabled)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: stateFileURL(), options: .atomic)
    }

    private func stateFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("NonSleep/state.json")
    }
}

private struct AppState: Codable {
    var enabled: Bool
}

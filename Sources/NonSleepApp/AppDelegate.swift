import AppKit
import Foundation
import IOKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isEnabled: Bool = false

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var stateFileDescriptor: Int32 = -1
    private var fileWatcher: DispatchSourceFileSystemObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureStateDir()
        loadState()
        syncAssertion()
        watchStateFile()
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseAssertion()
        fileWatcher?.cancel()
        if stateFileDescriptor >= 0 {
            Darwin.close(stateFileDescriptor)
        }
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

    // MARK: - IOKit Power Assertion

    private func syncAssertion() {
        if isEnabled {
            createAssertion()
        } else {
            releaseAssertion()
        }
    }

    private func createAssertion() {
        guard !hasAssertion else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "NonSleep: Preventing system sleep" as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            hasAssertion = true
        }
    }

    private func releaseAssertion() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        hasAssertion = false
        assertionID = 0
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

    private func watchStateFile() {
        let url = stateFileURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            saveState()
        }

        stateFileDescriptor = open(url.path, O_EVTONLY)
        guard stateFileDescriptor >= 0 else { return }

        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: stateFileDescriptor,
            eventMask: [.write, .rename],
            queue: .main
        )
        fileWatcher?.setEventHandler { [weak self] in
            guard let self else { return }
            let old = self.isEnabled
            self.loadState()
            if self.isEnabled != old {
                self.syncAssertion()
            }
        }
        fileWatcher?.setCancelHandler { [weak self] in
            if let fd = self?.stateFileDescriptor, fd >= 0 {
                Darwin.close(fd)
                self?.stateFileDescriptor = -1
            }
        }
        fileWatcher?.resume()
    }

    private func stateFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("NonSleep/state.json")
    }
}

private struct AppState: Codable {
    var enabled: Bool
}

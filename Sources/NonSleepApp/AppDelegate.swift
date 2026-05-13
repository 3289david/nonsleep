import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isEnabled: Bool = false

    private var stateFileDescriptor: Int32 = -1
    private var fileWatcher: DispatchSourceFileSystemObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadState()
        watchStateFile()
    }

    func applicationWillTerminate(_ notification: Notification) {
        fileWatcher?.cancel()
        if stateFileDescriptor >= 0 {
            close(stateFileDescriptor)
        }
    }

    private func loadState() {
        let url = stateFileURL()
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            isEnabled = false
            return
        }
        isEnabled = state.enabled
    }

    private func watchStateFile() {
        let url = stateFileURL()

        if !FileManager.default.fileExists(atPath: url.path) {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? "{}".data(using: .utf8)?.write(to: url)
        }

        stateFileDescriptor = open(url.path, O_EVTONLY)
        guard stateFileDescriptor >= 0 else { return }

        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: stateFileDescriptor,
            eventMask: [.write, .rename],
            queue: .main
        )
        fileWatcher?.setEventHandler { [weak self] in
            self?.loadState()
        }
        fileWatcher?.setCancelHandler { [weak self] in
            if let fd = self?.stateFileDescriptor, fd >= 0 {
                Darwin.close(fd)
                self?.stateFileDescriptor = -1
            }
        }
        fileWatcher?.resume()
    }

    func toggle() {
        isEnabled.toggle()
        saveState()
    }

    func enable() {
        isEnabled = true
        saveState()
    }

    func disable() {
        isEnabled = false
        saveState()
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

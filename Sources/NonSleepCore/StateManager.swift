import Foundation

public struct NonSleepState: Codable, Equatable {
    public var enabled: Bool
    public var temporaryUntil: Date?

    public init(enabled: Bool = false, temporaryUntil: Date? = nil) {
        self.enabled = enabled
        self.temporaryUntil = temporaryUntil
    }
}

public final class StateManager {
    public static let shared = StateManager()

    public static var stateDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("NonSleep")
    }

    public static var stateFileURL: URL {
        stateDirectory.appendingPathComponent("state.json")
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default

    private init() {
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        let dir = Self.stateDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    public func read() -> NonSleepState {
        let url = Self.stateFileURL
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(NonSleepState.self, from: data) else {
            return NonSleepState()
        }
        if let until = state.temporaryUntil, until < Date() {
            let expired = NonSleepState(enabled: false)
            write(expired)
            return expired
        }
        return state
    }

    public func write(_ state: NonSleepState) {
        ensureDirectoryExists()
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: Self.stateFileURL, options: .atomic)
    }

    public func enable() {
        write(NonSleepState(enabled: true))
    }

    public func disable() {
        write(NonSleepState(enabled: false))
    }

    public func toggle() -> Bool {
        let current = read()
        let newState = NonSleepState(enabled: !current.enabled)
        write(newState)
        return newState.enabled
    }

    public func enableTemporary(duration: TimeInterval) {
        let until = Date().addingTimeInterval(duration)
        write(NonSleepState(enabled: true, temporaryUntil: until))
    }
}

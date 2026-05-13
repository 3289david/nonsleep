import Foundation

public final class NonSleepController {
    public static let shared = NonSleepController()

    private let power = PowerManager.shared
    private let state = StateManager.shared
    private let lid = LidWatcher.shared

    public var onStateChanged: ((Bool) -> Void)?

    private init() {}

    public func start() {
        let current = state.read()
        if current.enabled {
            power.preventSleep()
        }

        lid.onLidStateChanged = { [weak self] lidState in
            self?.handleLidChange(lidState)
        }
        lid.start()
    }

    public func stop() {
        lid.stop()
        power.allowSleep()
    }

    public func enable() {
        state.enable()
        power.preventSleep()
        onStateChanged?(true)
    }

    public func disable() {
        state.disable()
        power.allowSleep()
        onStateChanged?(false)
    }

    @discardableResult
    public func toggle() -> Bool {
        let newEnabled = state.toggle()
        if newEnabled {
            power.preventSleep()
        } else {
            power.allowSleep()
        }
        onStateChanged?(newEnabled)
        return newEnabled
    }

    public func enableTemporary(hours: Double) {
        state.enableTemporary(duration: hours * 3600)
        power.preventSleep()
        onStateChanged?(true)

        DispatchQueue.global().asyncAfter(deadline: .now() + hours * 3600) { [weak self] in
            guard let self else { return }
            let s = self.state.read()
            if let until = s.temporaryUntil, until <= Date() {
                self.disable()
            }
        }
    }

    public var isEnabled: Bool {
        state.read().enabled
    }

    private func handleLidChange(_ lidState: LidState) {
        let s = state.read()
        guard s.enabled else { return }

        switch lidState {
        case .closed:
            power.preventSleep()
            power.sleepDisplay()
        case .open:
            power.wakeDisplay()
        }
    }
}

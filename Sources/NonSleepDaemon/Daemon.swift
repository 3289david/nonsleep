import Foundation
import NonSleepCore

@main
struct NonSleepDaemon {
    static func main() {
        let controller = NonSleepController.shared
        controller.start()

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let state = StateManager.shared.read()
            if state.enabled {
                if !PowerManager.shared.isSleepPrevented {
                    PowerManager.shared.preventSleep()
                }
            } else {
                if PowerManager.shared.isSleepPrevented {
                    PowerManager.shared.allowSleep()
                }
            }
        }

        signal(SIGTERM, SIG_IGN)
        let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigterm.setEventHandler {
            controller.stop()
            exit(0)
        }
        sigterm.resume()

        dispatchMain()
    }
}

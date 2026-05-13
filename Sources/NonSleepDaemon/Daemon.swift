import Foundation
import NonSleepCore

@main
struct NonSleepDaemon {
    static func main() {
        let controller = NonSleepController.shared
        controller.start()

        let stateURL = StateManager.stateFileURL
        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: open(stateURL.path, O_EVTONLY),
            eventMask: .write,
            queue: .main
        )

        watcher.setEventHandler {
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
        watcher.resume()

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

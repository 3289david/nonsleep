import Foundation
import IOKit

public enum LidState {
    case open
    case closed
}

public final class LidWatcher {
    public static let shared = LidWatcher()

    public var onLidStateChanged: ((LidState) -> Void)?
    private var notifyPort: IONotificationPortRef?
    private var notification: io_object_t = 0
    private var lastKnownState: LidState = .open
    private var timer: DispatchSourceTimer?

    private init() {}

    public func start() {
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer?.schedule(deadline: .now(), repeating: .seconds(2))
        timer?.setEventHandler { [weak self] in
            self?.checkLidState()
        }
        timer?.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public func currentLidState() -> LidState {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleACPIPlatformExpert"))
        guard service != MACH_PORT_NULL else { return .open }
        defer { IOObjectRelease(service) }

        var iterator: io_iterator_t = 0
        let kr = IORegistryEntryCreateIterator(service, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator)
        guard kr == KERN_SUCCESS else { return .open }
        defer { IOObjectRelease(iterator) }

        var entry: io_object_t
        repeat {
            entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }

            if let prop = IORegistryEntryCreateCFProperty(entry, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0) {
                let clamshellClosed = prop.takeRetainedValue() as? Bool ?? false
                return clamshellClosed ? .closed : .open
            }
        } while entry != 0

        return .open
    }

    private func checkLidState() {
        let current = currentLidState()
        if current != lastKnownState {
            lastKnownState = current
            DispatchQueue.main.async { [weak self] in
                self?.onLidStateChanged?(current)
            }
        }
    }
}

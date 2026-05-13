import Foundation
import IOKit
import IOKit.pwr_mgt

public final class PowerManager {
    public static let shared = PowerManager()

    private var assertionID: IOPMAssertionID = 0
    private var isAsserted = false

    private init() {}

    @discardableResult
    public func preventSleep(reason: String = "NonSleep: User requested sleep prevention") -> Bool {
        guard !isAsserted else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isAsserted = true
            return true
        }
        return false
    }

    @discardableResult
    public func allowSleep() -> Bool {
        guard isAsserted else { return true }
        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            isAsserted = false
            assertionID = 0
            return true
        }
        return false
    }

    public var isSleepPrevented: Bool {
        isAsserted
    }

    public func sleepDisplay() {
        let port = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IODisplayWrangler")
        if port != MACH_PORT_NULL {
            IORegistryEntrySetCFProperty(port, "IORequestIdle" as CFString, kCFBooleanTrue)
            IOObjectRelease(port)
        }
    }

    public func wakeDisplay() {
        let port = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IODisplayWrangler")
        if port != MACH_PORT_NULL {
            IORegistryEntrySetCFProperty(port, "IORequestIdle" as CFString, kCFBooleanFalse)
            IOObjectRelease(port)
        }
    }
}

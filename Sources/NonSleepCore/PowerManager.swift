import Foundation
import IOKit
import IOKit.pwr_mgt

public final class PowerManager {
    public static let shared = PowerManager()

    private var systemAssertionID: IOPMAssertionID = 0
    private var idleAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion = false
    private var hasIdleAssertion = false

    private init() {}

    @discardableResult
    public func preventSleep(reason: String = "NonSleep: User requested sleep prevention") -> Bool {
        var ok = true

        if !hasSystemAssertion {
            let r1 = IOPMAssertionCreateWithName(
                "PreventSystemSleep" as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                (reason + " (clamshell)") as CFString,
                &systemAssertionID
            )
            if r1 == kIOReturnSuccess { hasSystemAssertion = true } else { ok = false }
        }

        if !hasIdleAssertion {
            let r2 = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                (reason + " (idle)") as CFString,
                &idleAssertionID
            )
            if r2 == kIOReturnSuccess { hasIdleAssertion = true } else { ok = false }
        }

        return ok
    }

    @discardableResult
    public func allowSleep() -> Bool {
        var ok = true

        if hasSystemAssertion {
            if IOPMAssertionRelease(systemAssertionID) == kIOReturnSuccess {
                hasSystemAssertion = false
                systemAssertionID = 0
            } else { ok = false }
        }

        if hasIdleAssertion {
            if IOPMAssertionRelease(idleAssertionID) == kIOReturnSuccess {
                hasIdleAssertion = false
                idleAssertionID = 0
            } else { ok = false }
        }

        return ok
    }

    public var isSleepPrevented: Bool {
        hasSystemAssertion || hasIdleAssertion
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

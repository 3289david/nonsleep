import ArgumentParser
import Foundation
import NonSleepCore

@main
struct NonSleepCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nonsleep",
        abstract: "Prevent macOS from sleeping when the lid is closed.",
        version: "1.2.0",
        subcommands: [Enable.self, Stop.self, Status.self, Toggle.self, Temporary.self],
        defaultSubcommand: Enable.self
    )
}

struct Enable: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enable sleep prevention (foreground, holds assertion)."
    )

    func run() {
        StateManager.shared.enable()
        let power = PowerManager.shared
        power.preventSleep()

        print("● NonSleep enabled")
        print("  Sleep prevention active. Press Ctrl+C to stop.")
        print("  Verify: pmset -g assertions | grep NonSleep")

        let lid = LidWatcher.shared
        lid.onLidStateChanged = { state in
            switch state {
            case .closed:
                power.sleepDisplay()
            case .open:
                power.wakeDisplay()
            }
        }
        lid.start()

        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            lid.stop()
            power.allowSleep()
            StateManager.shared.disable()
            print("\n○ NonSleep disabled")
            Foundation.exit(0)
        }
        source.resume()

        dispatchMain()
    }
}

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Disable sleep prevention."
    )

    func run() {
        StateManager.shared.disable()
        print("○ NonSleep disabled")
        print("  (state written — daemon/app will release assertion)")
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show current status."
    )

    func run() {
        let state = StateManager.shared.read()
        let lid = LidWatcher.shared.currentLidState()

        if state.enabled {
            print("● NonSleep: ON")
        } else {
            print("○ NonSleep: OFF")
        }

        if let until = state.temporaryUntil {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: until, relativeTo: Date())
            print("  Timer: expires \(relative)")
        }

        print("  Lid: \(lid == .open ? "open" : "closed")")

        let pipe = Pipe()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "assertions"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let hasAssertion = output.contains("NonSleep")
        print("  Assertion: \(hasAssertion ? "ACTIVE" : "none")")
    }
}

struct Toggle: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Toggle sleep prevention state."
    )

    func run() {
        let enabled = StateManager.shared.toggle()
        print(enabled ? "● NonSleep: ON" : "○ NonSleep: OFF")
        print("  (state written — daemon/app will sync)")
    }
}

struct Temporary: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "for",
        abstract: "Enable for a duration (e.g., nonsleep for 2h)."
    )

    @Argument(help: "Duration like 1h, 30m, 2h30m")
    var duration: String

    func run() throws {
        guard let hours = parseDuration(duration) else {
            print("Invalid duration: \(duration)")
            print("Examples: 1h, 30m, 2h30m, 90m")
            throw ExitCode.failure
        }

        let minutes = Int(hours * 60)
        StateManager.shared.enableTemporary(duration: hours * 3600)
        let power = PowerManager.shared
        power.preventSleep()

        if minutes >= 60 {
            print("● NonSleep enabled for \(minutes / 60)h \(minutes % 60)m")
        } else {
            print("● NonSleep enabled for \(minutes)m")
        }
        print("  Press Ctrl+C to stop early.")

        let lid = LidWatcher.shared
        lid.onLidStateChanged = { state in
            switch state {
            case .closed: power.sleepDisplay()
            case .open: power.wakeDisplay()
            }
        }
        lid.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + hours * 3600) {
            lid.stop()
            power.allowSleep()
            StateManager.shared.disable()
            print("\n○ NonSleep: timer expired")
            Foundation.exit(0)
        }

        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            lid.stop()
            power.allowSleep()
            StateManager.shared.disable()
            print("\n○ NonSleep disabled")
            Foundation.exit(0)
        }
        source.resume()

        dispatchMain()
    }

    private func parseDuration(_ input: String) -> Double? {
        let pattern = #"(?:(\d+)h)?(?:(\d+)m)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }

        var totalHours: Double = 0

        if let hourRange = Range(match.range(at: 1), in: input), let h = Double(input[hourRange]) {
            totalHours += h
        }
        if let minRange = Range(match.range(at: 2), in: input), let m = Double(input[minRange]) {
            totalHours += m / 60.0
        }

        return totalHours > 0 ? totalHours : nil
    }
}

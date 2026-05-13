import ArgumentParser
import Foundation
import NonSleepCore

@main
struct NonSleepCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nonsleep",
        abstract: "Prevent macOS from sleeping when the lid is closed.",
        version: "1.0.0",
        subcommands: [Enable.self, Stop.self, Status.self, Toggle.self, Temporary.self],
        defaultSubcommand: Enable.self
    )
}

struct Enable: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enable sleep prevention."
    )

    func run() {
        let controller = NonSleepController.shared
        controller.enable()
        print("● NonSleep enabled")

        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            controller.disable()
            print("\n○ NonSleep disabled")
            Foundation.exit(0)
        }
        source.resume()

        controller.start()
        print("  Sleep prevention active. Press Ctrl+C to stop.")
        dispatchMain()
    }
}

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Disable sleep prevention."
    )

    func run() {
        NonSleepController.shared.disable()
        print("○ NonSleep disabled")
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
            print("  Temporary: expires \(relative)")
        }

        print("  Lid: \(lid == .open ? "open" : "closed")")
    }
}

struct Toggle: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Toggle sleep prevention."
    )

    func run() {
        let enabled = NonSleepController.shared.toggle()
        print(enabled ? "● NonSleep: ON" : "○ NonSleep: OFF")
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

        let controller = NonSleepController.shared
        controller.enableTemporary(hours: hours)

        let minutes = Int(hours * 60)
        if minutes >= 60 {
            print("● NonSleep enabled for \(minutes / 60)h \(minutes % 60)m")
        } else {
            print("● NonSleep enabled for \(minutes)m")
        }

        controller.start()

        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            controller.disable()
            print("\n○ NonSleep disabled")
            Foundation.exit(0)
        }
        source.resume()

        print("  Press Ctrl+C to stop early.")
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

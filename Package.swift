// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NonSleep",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "nonsleep", targets: ["NonSleepCLI"]),
        .executable(name: "nonsleepd", targets: ["NonSleepDaemon"]),
        .library(name: "NonSleepCore", targets: ["NonSleepCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "NonSleepCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "NonSleepCLI",
            dependencies: [
                "NonSleepCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "NonSleepDaemon",
            dependencies: ["NonSleepCore"]
        ),
    ]
)

// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "WaterCupReminder",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "WaterCupReminder", targets: ["WaterCupReminder"])
    ],
    targets: [
        .executableTarget(
            name: "WaterCupReminder",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)

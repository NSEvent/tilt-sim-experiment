// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TiltSim",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TiltSim",
            path: "TiltSim",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        )
    ]
)

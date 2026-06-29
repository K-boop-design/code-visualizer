// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeVisualizer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "CodeVisualizer",
            resources: [
                .copy("../../PythonService"),
                .copy("../../Resources/samples"),
            ]
        ),
    ]
)

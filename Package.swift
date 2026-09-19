// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PS3RichPresence",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PS3RichPresence", targets: ["PS3RichPresence"])
    ],
    targets: [
        .executableTarget(name: "PS3RichPresence")
    ]
)

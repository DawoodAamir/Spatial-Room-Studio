// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "RoomCore", platforms: [.macOS("27.0"), .visionOS("27.0")], products: [.library(name: "RoomCore", targets: ["RoomCore"])], targets: [.target(name: "RoomCore", path: "Sources/Core"), .testTarget(name: "RoomTests", dependencies: ["RoomCore"], path: "Tests/Core")])

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lucius",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Lucius", targets: ["Lucius"])],
    targets: [
        .target(name: "CProcess", publicHeadersPath: "include"),
        .target(name: "LuciusCore", dependencies: ["CProcess"]),
        .executableTarget(name: "Lucius", dependencies: ["LuciusCore"]),
        .testTarget(name: "LuciusCoreTests", dependencies: ["LuciusCore", "CProcess"])
    ]
)

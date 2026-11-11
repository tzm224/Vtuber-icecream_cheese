// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheeseDesktop",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CheesePet", targets: ["CheesePet"])],
    targets: [
        .target(name: "CheeseCore"),
        .executableTarget(name: "CheesePet", dependencies: ["CheeseCore"]),
        .testTarget(name: "CheeseCoreTests", dependencies: ["CheeseCore"])
    ]
)

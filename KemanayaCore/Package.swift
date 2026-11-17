// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KemanayaCore",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "KemanayaCore", targets: ["KemanayaCore"]),
    ],
    targets: [
        .target(name: "KemanayaCore"),
        .testTarget(name: "KemanayaCoreTests", dependencies: ["KemanayaCore"]),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KlickSea",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "KlickSea", targets: ["KlickSea"])],
    targets: [
        .executableTarget(name: "KlickSea"),
        .testTarget(name: "KlickSeaTests", dependencies: ["KlickSea"])
    ],
    swiftLanguageModes: [.v5]
)

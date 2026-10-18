// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhaseCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PhaseCore", targets: ["PhaseCore"])],
    targets: [
        .target(name: "PhaseCore"),
        .testTarget(name: "PhaseCoreTests", dependencies: ["PhaseCore"])
    ],
    swiftLanguageVersions: [.v5]
)

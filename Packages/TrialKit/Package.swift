// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrialKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TrialCore", targets: ["TrialCore"]),
        .library(name: "TrialUI", targets: ["TrialUI"])
    ],
    targets: [
        .target(name: "TrialCore", resources: [.process("Resources")]),
        .target(name: "TrialUI", dependencies: ["TrialCore"], resources: [.process("Resources")]),
        .testTarget(name: "TrialCoreTests", dependencies: ["TrialCore"])
    ]
)

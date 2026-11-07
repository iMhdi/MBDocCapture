// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MBDocCapture",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MBDocCapture", targets: ["MBDocCapture"])
    ],
    targets: [
        .target(
            name: "MBDocCapture",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MBDocCaptureTests",
            dependencies: ["MBDocCapture"]
        )
    ],
    swiftLanguageModes: [.v5]
)

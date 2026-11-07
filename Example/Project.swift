import ProjectDescription

// Regenerate with `tuist generate` after editing; the generated project is committed so Tuist is not required to run the demo.
let project = Project(
    name: "MBDocCaptureExample",
    packages: [.local(path: "..")],
    targets: [
        .target(
            name: "MBDocCaptureExample",
            destinations: .iOS,
            product: .app,
            bundleId: "com.github.imhdi.MBDocCaptureExample",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "NSCameraUsageDescription": "The camera is used to scan documents.",
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "CFBundleLocalizations": ["en", "fr"]
            ]),
            sources: ["Sources/**"],
            dependencies: [.package(product: "MBDocCapture")]
        )
    ]
)

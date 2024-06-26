// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kronos",
    products: [
        .library(
            name: "Kronos",
            targets: ["Kronos"]),
    ],
    targets: [
        .target(
            name: "Kronos",
            path: "Sources",
            resources: [.process("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "KronosTests",
            dependencies: ["Kronos"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StemJSON",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "StemJSON",
            targets: ["StemJSON"]
        ),
    ],
    targets: [
        .target(
            name: "StemJSON",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)

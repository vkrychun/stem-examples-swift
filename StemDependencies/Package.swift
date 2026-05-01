// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StemDependencies",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "StemDependencies", targets: ["StemDependencies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vkrychun/stem-runtime-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.12.0"),
    ],
    targets: [
        .target(
            name: "StemDependencies",
            dependencies: [
                .product(name: "StemRuntimeSDK", package: "stem-runtime-swift"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ]
        ),
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ENVI",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "ENVI", targets: ["ENVI"])
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.19.0"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.0"),
    ],
    targets: [
        .target(
            name: "ENVI",
            dependencies: [
                "SDWebImage",
                .product(name: "Lottie", package: "lottie-spm"),
            ],
            path: "ENVI",
            resources: [
                .process("Resources/Fonts"),
                .process("Resources/Images"),
            ]
        ),
        .testTarget(
            name: "ENVITests",
            dependencies: ["ENVI"],
            path: "ENVITests"
        ),
    ]
)

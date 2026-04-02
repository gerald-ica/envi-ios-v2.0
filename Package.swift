// swift-tools-version: 5.9
//
// ENVI iOS — Personalized AI Content Editor
//
// Dependency structure:
//   ENVI (main target)
//   ├── Core/AI/          — ENVI Brain: autoresearch-based AI engine (ENVIBrain, PredictionEngine,
//   │                       ContentAnalyzer, TrendForecaster, InsightGenerator, ExperimentTracker,
//   │                       ResearchLoop, ENVIBrainConfig) — no external dependencies, pure Swift
//   ├── Models/            — ContentPiece, ContentPrediction, ContentInsight, ChatThread, etc.
//   ├── SDWebImage         — Image loading & caching for content library thumbnails
//   ├── Lottie             — Animation playback for onboarding and transitions
//   ├── RevenueCat         — In-app purchase & subscription management
//   └── RevenueCatUI       — Pre-built paywalls & Customer Center
//
import PackageDescription

let package = Package(
    name: "ENVI",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "ENVI", targets: ["ENVI"])
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.19.0"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ENVI",
            dependencies: [
                "SDWebImage",
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
                .product(name: "RevenueCatUI", package: "purchases-ios-spm"),
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

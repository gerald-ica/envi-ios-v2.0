// swift-tools-version: 6.2
//
// ENVI iOS — Personalized AI Content Editor
//
// Dependency structure:
//   ENVI (main target)
//   ├── Core/AI/          — ENVI Brain: autoresearch-based AI engine (pure Swift, no deps)
//   ├── Models/            — ContentPiece, ContentPrediction, ContentInsight, ChatThread, etc.
//   ├── SDWebImage         — Image loading & caching for content library thumbnails
//   ├── Lottie             — Animation playback for onboarding and transitions
//   ├── RevenueCat         — In-app purchase & subscription management
//   ├── RevenueCatUI       — Pre-built paywalls & Customer Center
//   ├── FirebaseAuth       — Authentication (email + Apple Sign-In)
//   ├── FirebaseAnalytics  — Product analytics and event tracking
//   ├── FirebaseCrashlytics — Crash reporting and diagnostics
//   └── FirebaseCore       — Firebase SDK foundation
//
import PackageDescription

let package = Package(
    name: "ENVI",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .executable(name: "ENVI", targets: ["ENVI"])
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.19.0"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ENVI",
            dependencies: [
                "SDWebImage",
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
                .product(name: "RevenueCatUI", package: "purchases-ios-spm"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
            ],
            path: "ENVI",
            resources: [
                .process("Resources/Fonts"),
                .process("Resources/Images"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "ENVITests",
            dependencies: ["ENVI"],
            path: "ENVITests"
        ),
    ]
)

// swift-tools-version: 5.9
// EventFlow Package Dependencies
//
// このファイルは、Xcodeプロジェクトで使用するSwift Package Manager依存関係を文書化します。
// 実際のXcodeプロジェクトでは、File > Add Package Dependencies から追加してください。

import PackageDescription

let package = Package(
    name: "EventFlow",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "EventFlow",
            targets: ["EventFlow"])
    ],
    dependencies: [
        // Firebase SDK
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
        
        // SwiftCheck（プロパティベーステスト用）
        // .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0")
    ],
    targets: [
        .target(
            name: "EventFlow",
            dependencies: [
                // Firebase依存関係
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "EventFlowTests",
            dependencies: [
                "EventFlow",
                // .product(name: "SwiftCheck", package: "SwiftCheck")
            ]
        )
    ]
)

// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VoxScript",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoxScript", targets: ["VoxScript"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "VoxScript",
            dependencies: [
                "WhisperKit",
                "KeyboardShortcuts"
            ],
            path: "VoxScript",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VoxScriptTests",
            dependencies: ["VoxScript"],
            path: "VoxScriptTests"
        )
    ]
)

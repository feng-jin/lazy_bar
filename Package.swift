// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "lazy_bar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "lazy_bar",
            targets: ["LazyBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LazyBar",
            path: "Sources"
        )
    ]
)

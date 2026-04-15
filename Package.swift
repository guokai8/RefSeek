// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RefSeek",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "RefSeek", targets: ["RefSeek"])
    ],
    targets: [
        .executableTarget(
            name: "RefSeek",
            path: "Sources/RefSeek",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)

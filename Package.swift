// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SovereignStandard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SovereignStandard",
            targets: ["SovereignStandard"]
        )
    ],
    dependencies: [
        .package(path: "./FoldKernel"),
        .package(path: "./SigilEngine")
    ],
    targets: [
        .executableTarget(
            name: "SovereignStandard",
            dependencies: [
                .product(name: "FoldKernel", package: "FoldKernel"),
                .product(name: "SigilEngine", package: "SigilEngine")
            ],
            path: "SovereignStandard/SovereignStandard",
            exclude: [
                "Assets.xcassets"
            ]
        ),
        .testTarget(
            name: "SovereignStandardTests",
            dependencies: ["SovereignStandard"],
            path: "Tests/SovereignStandardTests"
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SigilEngine",
    products: [
        .library(
            name: "SigilEngine",
            targets: ["SigilEngine"]
        )
    ],
    dependencies: [
        .package(path: "../FoldKernel")
    ],
    targets: [
        .target(
            name: "SigilEngine",
            dependencies: [
                .product(name: "FoldKernel", package: "FoldKernel")
            ]
        )
    ]
)

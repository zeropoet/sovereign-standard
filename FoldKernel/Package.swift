// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FoldKernel",
    products: [
        .library(
            name: "FoldKernel",
            targets: ["FoldKernel"]
        )
    ],
    targets: [
        .target(
            name: "FoldKernel"
        ),
        .testTarget(
            name: "FoldKernelTests",
            dependencies: ["FoldKernel"]
        )
    ]
)

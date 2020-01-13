// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SJDataStructures",
    products: [
        .library(name: "SJDataStructures", targets: ["SJDataStructures"]),
    ],
    targets: [
        .target(name: "SJDataStructures"),
        .testTarget(name: "SJDataStructuresTests", dependencies: ["SJDataStructures"]),
    ]
)

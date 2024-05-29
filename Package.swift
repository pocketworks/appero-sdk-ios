// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Appero",
    platforms: [
            .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Appero",
            targets: ["Appero"]),
        
    ],
    dependencies: [
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Appero",
            resources: [
                .copy("Media.xcassets")
            ]
        ),
        .testTarget(
            name: "ApperoTests",
            dependencies: ["Appero"]
        ),
    ]
//    swiftLanguageVersions: [
//        .v5
//    ]
)

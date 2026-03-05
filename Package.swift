// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Legado",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "LegadoCore", targets: ["LegadoCore"])
    ],
    dependencies: [
        // Readium Swift Toolkit - EPUB 支持
        .package(url: "https://github.com/nickaroot/readium-swift-toolkit.git", from: "3.5.0"),
        
        // HTML 解析
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        
        // XPath
        .package(url: "https://github.com/tadija/AEXML.git", from: "4.6.0")
    ],
    targets: [
        .target(
            name: "LegadoCore",
            dependencies: [
                .product(name: "ReadiumShared", package: "readium-swift-toolkit"),
                .product(name: "ReadiumStreamer", package: "readium-swift-toolkit"),
                .product(name: "ReadiumNavigator", package: "readium-swift-toolkit"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ],
            path: "Core"
        ),
        .testTarget(
            name: "LegadoCoreTests",
            dependencies: ["LegadoCore"],
            path: "Tests/Unit"
        )
    ]
)
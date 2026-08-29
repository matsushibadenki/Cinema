// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Cinema",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Cinema", targets: ["Cinema"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Cinema",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Cinema",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Cinema/Resources/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "CinemaTests",
            dependencies: ["Cinema"],
            path: "Tests/CinemaTests"
        )
    ]
)

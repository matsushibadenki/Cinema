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
    targets: [
        .executableTarget(
            name: "Cinema",
            path: "Sources/Cinema",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags([
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

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Buehne",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "BuehneCore", targets: ["BuehneCore"]),
        .library(name: "BuehneEngine", targets: ["BuehneEngine"]),
        .library(name: "BuehneUI", targets: ["BuehneUI"]),
        .executable(name: "Buehne", targets: ["Buehne"]),
        .executable(name: "BuehneSelfCheck", targets: ["BuehneSelfCheck"]),
    ],
    targets: [
        .target(name: "BuehneCore"),
        .target(
            name: "Cmpv",
            path: "Sources/Cmpv",
            publicHeadersPath: "include",
            cSettings: [.unsafeFlags(["-I/opt/homebrew/opt/mpv/include"])],
            linkerSettings: [
                .linkedLibrary("mpv"),
                .linkedFramework("OpenGL"),
                .linkedFramework("IOSurface"),
                .linkedFramework("CoreVideo"),
                .unsafeFlags(["-L/opt/homebrew/opt/mpv/lib"]),
            ]
        ),
        .target(
            name: "BuehneEngine",
            dependencies: ["BuehneCore", "Cmpv"],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("IOSurface"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .target(
            name: "BuehneUI",
            dependencies: ["BuehneCore", "BuehneEngine"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "Buehne", dependencies: ["BuehneCore", "BuehneUI"]),
        .executableTarget(name: "BuehneSelfCheck", dependencies: ["BuehneCore", "BuehneEngine", "BuehneUI"]),
        .testTarget(name: "BuehneCoreTests", dependencies: ["BuehneCore"]),
        .testTarget(name: "BuehneUITests", dependencies: ["BuehneUI"]),
    ]
)

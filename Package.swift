// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExSplit",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "exsplit", targets: ["ExSplitCLI"]),
        .executable(name: "ExSplitApp", targets: ["ExSplitApp"]),
    ],
    targets: [
        // Motor: detección de ejercicios + maquetación. Solo frameworks de Apple (PDFKit, CoreGraphics, Vision).
        .target(name: "ExSplitCore"),
        .executableTarget(name: "ExSplitCLI", dependencies: ["ExSplitCore"]),
        .executableTarget(name: "ExSplitApp", dependencies: ["ExSplitCore"]),
    ],
    swiftLanguageVersions: [.v5]
)

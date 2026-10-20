// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SplitExercises",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "splitexercises", targets: ["SplitExercisesCLI"]),
        .executable(name: "SplitExercisesApp", targets: ["SplitExercisesApp"]),
    ],
    targets: [
        // Motor: detección de ejercicios + maquetación. Solo frameworks de Apple (PDFKit, CoreGraphics, Vision).
        .target(name: "SplitExercisesCore"),
        .executableTarget(name: "SplitExercisesCLI", dependencies: ["SplitExercisesCore"]),
        .executableTarget(name: "SplitExercisesApp", dependencies: ["SplitExercisesCore"]),
    ],
    swiftLanguageVersions: [.v5]
)

// swift-tools-version: 6.0
// Cœur logique de NOYA SSH Manager : modèles, validation, lecture de la
// configuration SSH et construction des commandes. Uniquement Foundation,
// afin d'être testable sur macOS comme sur Linux.
import PackageDescription

let package = Package(
    name: "NoyaCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NoyaCore", targets: ["NoyaCore"]),
    ],
    targets: [
        .target(name: "NoyaCore"),
        .testTarget(name: "NoyaCoreTests", dependencies: ["NoyaCore"]),
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VisoreKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VisoreKit", targets: ["VisoreKit"])],
    targets: [
        .target(name: "VisoreKit", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "VisoreKitTests", dependencies: ["VisoreKit"],
                    resources: [.copy("Vettori")]),
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Diary",
    platforms: [
        .macOS("14.0")
    ],
    products: [
        .executable(name: "Diary", targets: ["Diary"])
    ],
    targets: [
        .executableTarget(
            name: "Diary"
        )
    ]
)

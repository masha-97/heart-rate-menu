// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HeartRateMenu",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "HeartRateMenu", targets: ["HeartRateMenu"])],
    targets: [.executableTarget(name: "HeartRateMenu")]
)

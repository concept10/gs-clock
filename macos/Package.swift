// swift-tools-version:5.9
import PackageDescription

let package = Package(
	name: "CairoClock",
	platforms: [.macOS(.v13)],
	targets: [
		.executableTarget(name: "CairoClock", path: "Sources/CairoClock"),
	]
)

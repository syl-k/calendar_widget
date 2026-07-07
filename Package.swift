// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CalendarWidget",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CalendarWidget",
            path: "Sources/CalendarWidget"
        )
    ]
)

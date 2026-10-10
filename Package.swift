// swift-tools-version:6.0
//
// Unadly for macOS. `UnadlyCore` holds the platform-independent logic (address parsing,
// pins, content-blocker rules) so it can be unit tested; `Unadly` is the SwiftUI/WebKit app.

import PackageDescription

let package = Package(
    name: "Unadly",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Unadly", targets: ["Unadly"]),
        .library(name: "UnadlyCore", targets: ["UnadlyCore"]),
    ],
    targets: [
        .target(name: "UnadlyCore"),
        .executableTarget(
            name: "Unadly",
            dependencies: ["UnadlyCore"]
        ),
        .testTarget(
            name: "UnadlyCoreTests",
            dependencies: ["UnadlyCore"]
        ),
    ]
)

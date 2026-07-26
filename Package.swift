// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Reader3App",
    platforms: [.iOS(.v15)],
    targets: [
        .target(
            name: "Reader3App",
            path: ".",
            sources: [
                "Reader3App/DZMeBookRead/other/extension/String+Extension.swift",
            ]
        ),
    ]
)

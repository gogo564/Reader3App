// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Reader3App",
    platforms: [.iOS(.v15)],
    targets: [
        .target(
            name: "Reader3App",
            path: "Reader3App",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("DZMeBookRead/other/thirdParty/ASValueTrackingSlider"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/DZMCoverController"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/DZMMagnifierView"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/DZMSegmentedControl"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/FDFullscreenPopGesture"),
            ]
        ),
    ]
)

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Reader3App",
    platforms: [.iOS(.v15)],
    targets: [
        .target(
            name: "ObjCThirdParty",
            path: "Reader3App/DZMeBookRead/other/thirdParty",
            sources: [
                "ASValueTrackingSlider/ASValuePopUpView.m",
                "ASValueTrackingSlider/ASValueTrackingSlider.m",
                "DZMCoverController/DZMCoverController.m",
                "DZMMagnifierView/DZMMagnifierView.m",
                "DZMSegmentedControl/DZMSegmentedControl.m",
                "FDFullscreenPopGesture/UINavigationController+FDFullscreenPopGesture.m",
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("ASValueTrackingSlider"),
                .headerSearchPath("DZMCoverController"),
                .headerSearchPath("DZMMagnifierView"),
                .headerSearchPath("DZMSegmentedControl"),
                .headerSearchPath("FDFullscreenPopGesture"),
            ]
        ),
        .target(
            name: "Reader3App",
            dependencies: ["ObjCThirdParty"],
            path: "Reader3App",
            exclude: [
                "DZMeBookRead/other/thirdParty",
                "Assets.xcassets", "Info.plist",
            ],
            cSettings: [
                .headerSearchPath("DZMeBookRead/other"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/ASValueTrackingSlider"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/DZMCoverController"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/DZMMagnifierView"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/DZMSegmentedControl"),
                .headerSearchPath("DZMeBookRead/other/thirdParty/FDFullscreenPopGesture"),
            ],
            swiftSettings: [
            ]
        ),
    ]
)

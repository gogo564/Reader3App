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
                "DZMeBookRead/other/thirdParty/ASValueTrackingSlider",
                "DZMeBookRead/other/thirdParty/DZMCoverController",
                "DZMeBookRead/other/thirdParty/DZMMagnifierView",
                "DZMeBookRead/other/thirdParty/DZMSegmentedControl",
                "DZMeBookRead/other/thirdParty/FDFullscreenPopGesture",
            ]
        ),
    ]
)

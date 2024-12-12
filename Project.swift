import ProjectDescription

let project = Project(
    name: "V2Bar",
    options: .options(
        defaultKnownRegions: ["zh-Hans"],
        developmentRegion: "zh-Hans"
    ),
    packages: [
        .remote(url: "https://github.com/Alamofire/Alamofire", requirement: .upToNextMajor(from: "5.10.2")),
        .remote(url: "https://github.com/SwiftUIX/SwiftUIX", requirement: .upToNextMajor(from: "0.2.3")),
        .remote(url: "https://github.com/SwifterSwift/SwifterSwift", requirement: .upToNextMajor(from: "7.0.0")),
        .remote(url: "https://github.com/sindresorhus/Defaults", requirement: .upToNextMajor(from: "9.0.0"))
    ],
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "DEVELOPMENT_LANGUAGE": "zh-Hans"
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "V2Bar",
            destinations: .macOS,
            product: .app,
            bundleId: "top.ygsgdbd.V2Bar",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: [
                "LSUIElement": true,
                "CFBundleDevelopmentRegion": "zh-Hans",
                "NSHumanReadableCopyright": "Copyright © 2024 ygsgdbd. All rights reserved.",
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
                
                // 网络安全配置 - 允许所有 HTTPS 连接
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": false  // 只允许 HTTPS 连接
                ],
                
                // 网络权限描述
                "NSNetworkingUsageDescription": "V2Bar 需要访问网络以获取内容"
            ]),
            sources: ["V2Bar/Sources/**"],
            resources: ["V2Bar/Resources/**"],
            dependencies: [
                .package(product: "Alamofire"),
                .package(product: "SwiftUIX"),
                .package(product: "SwifterSwift"),
                .package(product: "Defaults")
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_LANGUAGE": "zh-Hans",
                    "SWIFT_VERSION": "5.9"
                ],
                configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release")
                ]
            )
        )
    ]
)

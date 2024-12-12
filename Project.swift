import ProjectDescription

let project = Project(
    name: "V2Bar",
    options: .options(
        defaultKnownRegions: ["zh-Hans", "zh-Hant", "en"],
        developmentRegion: "zh-Hans"
    ),
    packages: [
        .remote(url: "https://github.com/Alamofire/Alamofire", requirement: .upToNextMajor(from: "5.10.2")),
        .remote(url: "https://github.com/SwiftUIX/SwiftUIX", requirement: .upToNextMajor(from: "0.2.3")),
        .remote(url: "https://github.com/SwifterSwift/SwifterSwift", requirement: .upToNextMajor(from: "7.0.0"))
    ],
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "DEVELOPMENT_LANGUAGE": "zh-Hans",
            "SWIFT_EMIT_LOC_STRINGS": "YES"
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
                "CFBundleLocalizations": ["zh-Hans", "zh-Hant", "en"],
                "AppleLanguages": ["zh-Hans"],
                "NSHumanReadableCopyright": "Copyright © 2024 ygsgdbd. All rights reserved.",
                
                // 网络安全配置 - 允许所有 HTTPS 连接
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": false  // 只允许 HTTPS 连接
                ],
                
                // 网络权限描述
                "NSNetworkingUsageDescription": "V2Bar 需要访问网络以获取内容"
            ]),
            sources: ["V2Bar/Sources/**"],
            resources: [
                "V2Bar/Resources/**",
                .folderReference(path: "V2Bar/Resources/zh-Hans.lproj"),
                .folderReference(path: "V2Bar/Resources/zh-Hant.lproj"),
                .folderReference(path: "V2Bar/Resources/en.lproj")
            ],
            dependencies: [
                .package(product: "Alamofire"),
                .package(product: "SwiftUIX"),
                .package(product: "SwifterSwift")
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_LANGUAGE": "zh-Hans",
                    "SWIFT_VERSION": "5.9",
                    "SWIFT_EMIT_LOC_STRINGS": "YES"
                ],
                configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release")
                ]
            )
        )
    ]
)

import ProjectDescription

// MARK: - Version
let appVersion = "0.1.2"  // 应用版本号
let buildVersion = "@BUILD_NUMBER@"  // 构建版本号占位符，会被 GitHub Actions 替换

// 基础依赖
let baseDependencies: [TargetDependency] = [
    .package(product: "Alamofire"),
    .package(product: "SwiftUIX"),
    .package(product: "SwifterSwift"),
    .package(product: "Defaults")
]

// 开发环境依赖
let developmentDependencies: [TargetDependency] = baseDependencies + [
    .package(product: "Atlantis")
]

let baseSettings = Settings.settings(
    base: [
        "SWIFT_VERSION": "5.9",
        "DEVELOPMENT_LANGUAGE": "zh-Hans",
        "MARKETING_VERSION": SettingValue(stringLiteral: appVersion),
        "CURRENT_PROJECT_VERSION": SettingValue(stringLiteral: buildVersion)
    ],
    configurations: [
        .debug(name: "Debug"),
        .release(name: "Release")
    ]
)

let baseInfoPlist: [String: Plist.Value] = [
    "LSUIElement": .boolean(true),
    "CFBundleDevelopmentRegion": .string("zh-Hans"),
    "NSHumanReadableCopyright": .string("Copyright © 2024 ygsgdbd. All rights reserved."),
    "CFBundleShortVersionString": .string(appVersion),
    "CFBundleVersion": .string(buildVersion),
    "NSAppTransportSecurity": .dictionary([
        "NSAllowsArbitraryLoads": .boolean(false)
    ]),
    "NSNetworkingUsageDescription": .string("V2Bar 需要访问网络以获取内容")
]

// 开发环境额外的 Info.plist 配置
let developmentInfoPlist: [String: Plist.Value] = baseInfoPlist.merging([
    "NSLocalNetworkUsageDescription": .string("Atlantis uses Bonjour Service to send your recorded traffic to Proxyman app."),
    "NSBonjourServices": .array([
        .string("_Proxyman._tcp")
    ])
]) { (_, new) in new }

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
        .remote(url: "https://github.com/sindresorhus/Defaults", requirement: .upToNextMajor(from: "9.0.0")),
        .remote(url: "https://github.com/ProxymanApp/atlantis", requirement: .upToNextMajor(from: "1.26.0"))
    ],
    settings: baseSettings,
    targets: [
        // 发布版本 Target
        .target(
            name: "V2Bar",
            destinations: .macOS,
            product: .app,
            bundleId: "top.ygsgdbd.V2Bar",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: baseInfoPlist),
            sources: ["V2Bar/Sources/**"],
            resources: ["V2Bar/Resources/**"],
            dependencies: baseDependencies,
            settings: baseSettings
        ),
        // 开发版本 Target
        .target(
            name: "V2Bar-Dev",
            destinations: .macOS,
            product: .app,
            bundleId: "top.ygsgdbd.V2Bar.dev",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: developmentInfoPlist),
            sources: ["V2Bar/Sources/**"],
            resources: ["V2Bar/Resources/**"],
            dependencies: developmentDependencies,
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "5.9",
                    "DEVELOPMENT_LANGUAGE": "zh-Hans",
                    "OTHER_SWIFT_FLAGS": "-D DEBUG",
                    "OTHER_LDFLAGS": "$(inherited) -ObjC"
                ],
                configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release")
                ]
            )
        )
    ]
)

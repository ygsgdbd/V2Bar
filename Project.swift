import Foundation
import ProjectDescription

// MARK: - Version
let appVersion = Environment.appVersion.getString(default: "0.1.1")
let buildVersion = Environment.buildVersion.getString(default: "0")
let sparklePublicKey = ProcessInfo.processInfo.environment["TUIST_SPARKLE_PUBLIC_KEY"]
    ?? "iQt5X/HXFWmvB7pKxm7mxHZPXh2FG9UA8fFPmAKcE8I="

// 基础依赖
let baseDependencies: [TargetDependency] = [
    .package(product: "Alamofire"),
    .package(product: "CasePaths"),
    .package(product: "Clocks"),
    .package(product: "ComposableArchitecture"),
    .package(product: "Dependencies"),
    .package(product: "PerceptionCore"),
    .package(product: "Sharing"),
    .package(product: "Sparkle")
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
    "CFBundleExecutable": .string("$(EXECUTABLE_NAME)"),
    "CFBundleDevelopmentRegion": .string("zh-Hans"),
    "CFBundleIdentifier": .string("$(PRODUCT_BUNDLE_IDENTIFIER)"),
    "CFBundleInfoDictionaryVersion": .string("6.0"),
    "CFBundleName": .string("$(PRODUCT_NAME)"),
    "CFBundlePackageType": .string("APPL"),
    "LSApplicationCategoryType": .string("public.app-category.utilities"),
    "LSMinimumSystemVersion": .string("14.0"),
    "NSPrincipalClass": .string("NSApplication"),
    "NSHumanReadableCopyright": .string("Copyright © 2024 ygsgdbd. All rights reserved."),
    "CFBundleShortVersionString": .string(appVersion),
    "CFBundleVersion": .string(buildVersion),
    "NSAppTransportSecurity": .dictionary([
        "NSAllowsArbitraryLoads": .boolean(false)
    ]),
    "NSNetworkingUsageDescription": .string("V2Bar 需要访问网络以获取内容"),
    "SUFeedURL": .string("https://github.com/ygsgdbd/V2Bar/releases/latest/download/appcast.xml"),
    "SUEnableAutomaticChecks": .boolean(false),
    "SUPublicEDKey": .string(sparklePublicKey)
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
        .remote(url: "https://github.com/Alamofire/Alamofire", requirement: .exact("5.10.2")),
        .remote(url: "https://github.com/pointfreeco/swift-case-paths", requirement: .upToNextMajor(from: "1.7.3")),
        .remote(url: "https://github.com/pointfreeco/swift-composable-architecture", requirement: .exact("1.25.5")),
        .remote(url: "https://github.com/pointfreeco/swift-dependencies", requirement: .upToNextMajor(from: "1.12.0")),
        .remote(url: "https://github.com/pointfreeco/swift-perception", requirement: .upToNextMajor(from: "2.0.10")),
        .remote(url: "https://github.com/pointfreeco/swift-sharing", requirement: .upToNextMajor(from: "2.0.0")),
        .remote(url: "https://github.com/pointfreeco/swift-clocks", requirement: .exact("1.1.0")),
        .remote(url: "https://github.com/sparkle-project/Sparkle", requirement: .exact("2.9.4")),
        .remote(url: "https://github.com/ProxymanApp/atlantis", requirement: .exact("1.26.0"))
    ],
    settings: baseSettings,
    targets: [
        // 发布版本 Target
        .target(
            name: "V2Bar",
            destinations: .macOS,
            product: .app,
            bundleId: "top.ygsgdbd.V2Bar",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .dictionary(baseInfoPlist),
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
            deploymentTargets: .macOS("14.0"),
            infoPlist: .dictionary(developmentInfoPlist),
            sources: ["V2Bar/Sources/**"],
            resources: ["V2Bar/Resources/**"],
            dependencies: developmentDependencies,
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "5.9",
                    "DEVELOPMENT_LANGUAGE": "zh-Hans",
                    "OTHER_SWIFT_FLAGS": "$(inherited) -D V2BAR_DEV",
                    "OTHER_LDFLAGS": "$(inherited) -ObjC"
                ],
                configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release")
                ]
            )
        ),
        .target(
            name: "V2BarTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "top.ygsgdbd.V2BarTests",
            deploymentTargets: .macOS("14.0"),
            sources: ["V2BarTests/**"],
            dependencies: [
                .target(name: "V2Bar"),
                .package(product: "CasePaths"),
                .package(product: "ComposableArchitecture"),
                .package(product: "Clocks"),
                .package(product: "Dependencies"),
                .package(product: "Sharing")
            ],
            settings: baseSettings
        )
    ],
    schemes: [
        .scheme(
            name: "V2Bar",
            shared: true,
            buildAction: .buildAction(targets: ["V2Bar"]),
            testAction: .targets(["V2BarTests"]),
            runAction: .runAction(configuration: .debug, executable: "V2Bar"),
            archiveAction: .archiveAction(configuration: .release)
        ),
        .scheme(
            name: "V2Bar-Dev",
            shared: true,
            buildAction: .buildAction(targets: ["V2Bar-Dev"]),
            runAction: .runAction(configuration: .debug, executable: "V2Bar-Dev"),
            archiveAction: .archiveAction(configuration: .release)
        )
    ]
)

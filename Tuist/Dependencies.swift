import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: .init(
        [
            .remote(url: "https://github.com/Alamofire/Alamofire", requirement: .upToNextMajor(from: "5.8.1")),
            .remote(url: "https://github.com/SwiftUIX/SwiftUIX", requirement: .upToNextMajor(from: "0.1.9")),
            .remote(url: "https://github.com/SwifterSwift/SwifterSwift", requirement: .upToNextMajor(from: "6.0.0")),
            .remote(url: "https://github.com/pointfreeco/swift-sharing", requirement: .upToNextMajor(from: "0.2.0"))
        ],
        baseSettings: .settings(
            configurations: [
                .debug(name: .debug),
                .release(name: .release)
            ]
        )
    ),
    platforms: [.macOS]
) 
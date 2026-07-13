#if DEBUG
import AppKit
import CoreGraphics
import Foundation
import Sharing
import SwiftUI

struct ReadmeScreenshotConfiguration: Equatable {
    struct Display: Equatable {
        let id: CGDirectDisplayID
        let pixelWidth: Int
        let pixelHeight: Int

        var pixelArea: Int64 { Int64(pixelWidth) * Int64(pixelHeight) }
    }

    enum Appearance: String, Equatable {
        case light
        case dark
    }

    let appearance: Appearance
    let requestedDisplayID: CGDirectDisplayID?

    init?(arguments: [String]) {
        guard arguments.contains("--readme-demo") else { return nil }
        if let index = arguments.firstIndex(of: "--readme-appearance"),
           arguments.indices.contains(index + 1),
           let value = Appearance(rawValue: arguments[index + 1]) {
            appearance = value
        } else {
            appearance = .light
        }
        if let index = arguments.firstIndex(of: "--readme-display-id"),
           arguments.indices.contains(index + 1),
           let value = CGDirectDisplayID(arguments[index + 1]) {
            requestedDisplayID = value
        } else {
            requestedDisplayID = nil
        }
    }

    var appAppearance: NSAppearance {
        NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)!
    }

    var colorScheme: ColorScheme {
        appearance == .dark ? .dark : .light
    }

    @MainActor
    func applyAppearance() {
        NSApplication.shared.appearance = appAppearance
    }

    @MainActor
    func makeBackdropWindow() -> NSWindow? {
        let displayID = requestedDisplayID ?? Self.highestResolutionDisplayID(in: Self.onlineDisplays())
        let screen = NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        } ?? NSScreen.main
        guard let screen else { return nil }
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.appearance = appAppearance
        window.backgroundColor = appearance == .dark
            ? NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)
            : NSColor(srgbRed: 0.94, green: 0.95, blue: 0.97, alpha: 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.orderFrontRegardless()
        return window
    }

    static func highestResolutionDisplayID(in displays: [Display]) -> CGDirectDisplayID? {
        displays.max { lhs, rhs in
            if lhs.pixelArea != rhs.pixelArea { return lhs.pixelArea < rhs.pixelArea }
            if lhs.pixelWidth != rhs.pixelWidth { return lhs.pixelWidth < rhs.pixelWidth }
            return lhs.id < rhs.id
        }?.id
    }

    func initialState(now: Date) -> AppFeature.State {
        var state = AppFeature.State(token: "demo-token-12345678", isReadmeDemo: true)
        state.lastUpdated = now.addingTimeInterval(-120)
        state.launchAtLoginStatus = .enabled
        state.tokenInfo = V2EXTokenInfo(
            token: "demo-token-12345678",
            scope: "everything",
            expiration: 2_592_000,
            goodForDays: 30,
            totalUsed: 42,
            lastUsed: 1,
            created: 1
        )
        state.profile = V2EXUserProfile(
            id: 1,
            username: "yangguan",
            url: "https://www.v2ex.com/member/yangguan",
            website: "https://github.com/ygsgdbd",
            twitter: "ygsgdbd",
            psn: nil,
            github: "ygsgdbd",
            btc: nil,
            location: "Shanghai",
            tagline: "Stay hungry, stay foolish.",
            bio: nil,
            avatarMini: nil,
            avatarNormal: nil,
            avatarLarge: nil,
            avatarXlarge: nil,
            avatarXxlarge: nil,
            created: 1_609_459_200,
            lastModified: 1
        )
        state.avatarData = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)?.tiffRepresentation
        let demoNotifications: [(
            username: String,
            topicID: Int,
            topicTitle: String,
            action: String,
            payload: String?
        )] = [
            ("CSwater", 101, "TypeSwitch - macOS 自动切换输入法", "回复了主题", "试了，好用，非常感谢！"),
            ("wmwmmkk", 101, "TypeSwitch - macOS 自动切换输入法", "感谢了你发布的主题", nil),
            ("WilliamColton", 101, "TypeSwitch - macOS 自动切换输入法", "感谢了你发布的主题", nil),
            ("AccelerXu", 102, "V2Bar - 简洁优雅的 macOS 菜单栏应用", "回复了主题", "mac 到手已经 star 并用上了"),
            ("Shmily", 102, "V2Bar - 简洁优雅的 macOS 菜单栏应用", "收藏了你发布的主题", nil),
            ("OneEvent", 102, "V2Bar - 简洁优雅的 macOS 菜单栏应用", "感谢了你发布的主题", nil),
            ("linshang", 103, "VastWords - 自动监控您的剪贴板", "收藏了你发布的主题", nil),
            ("scorez", 103, "VastWords - 自动监控您的剪贴板", "收藏了你发布的主题", nil),
            ("OneEvent", 104, "有关 App 版本和状态栏的建议", "回复了主题", "有可能会有 App 版本嘛，状态栏的版本很好。"),
            ("callv", 104, "有关 App 版本和状态栏的建议", "回复了主题", "macOS 12 用不了。"),
        ]
        state.notifications = demoNotifications.enumerated().map { index, item in
            return V2EXNotification(
                id: index + 1,
                memberId: index + 1,
                forMemberId: 1,
                text: "<a href=\"/member/\(item.username)\">\(item.username)</a> \(item.action) <a href=\"/t/\(item.topicID)#reply\(index + 1)\">\(item.topicTitle)</a>",
                payload: item.payload,
                payloadRendered: item.payload ?? "",
                created: Int(now.timeIntervalSince1970) - index * 300,
                member: NotificationMember(username: item.username)
            )
        }
        state.knownNotificationIDs = Set(state.notifications.map(\.id))
        state.newNotificationIDs = [1]
        return state
    }

    private static func onlineDisplays() -> [Display] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { id in
            let mode = CGDisplayCopyDisplayMode(id)
            return Display(
                id: id,
                pixelWidth: mode?.pixelWidth ?? CGDisplayPixelsWide(id),
                pixelHeight: mode?.pixelHeight ?? CGDisplayPixelsHigh(id)
            )
        }
    }
}
#endif

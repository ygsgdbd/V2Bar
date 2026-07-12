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
        state.notifications = (0..<10).map { index in
            let username = index == 0 ? "alice" : "member\(index)"
            let topicTitle: String
            let action: String
            let payload: String?
            switch index % 3 {
            case 1:
                topicTitle = "TypeSwitch - macOS 自动切换输入法"
                action = "收藏了你发布的主题"
                payload = nil
            case 2:
                topicTitle = "V2Bar - 简洁优雅的 macOS 菜单栏应用"
                action = "感谢了你发布的主题"
                payload = nil
            default:
                topicTitle = index == 0 ? "欢迎使用 V2Bar" : "原生菜单与 TCA"
                action = "回复了主题"
                payload = index == 0
                    ? "原生菜单的最近回复现在更清晰了，正文一眼就能看到。"
                    : "这个原生菜单的交互很清晰，期待后续更新。"
            }
            return V2EXNotification(
                id: index + 1,
                memberId: index + 1,
                forMemberId: 1,
                text: "<a href=\"/member/\(username)\">\(username)</a> \(action) <a href=\"/t/\(100 + index)\">\(topicTitle)</a>",
                payload: payload,
                payloadRendered: payload ?? "",
                created: Int(now.timeIntervalSince1970) - index * 300,
                member: NotificationMember(username: username)
            )
        }
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

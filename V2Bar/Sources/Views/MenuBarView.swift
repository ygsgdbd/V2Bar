import AppKit
import ComposableArchitecture
import SwiftUI

struct MenuBarView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            accountSection

            Divider()

            v2exLinks

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
            }

            if store.hasToken {
                Divider()
                notificationsSection
            }

            Divider()

            tokenMenu

            Divider()

            autoRefreshControls
            launchAtLoginControls

            Button {
                store.send(.checkForUpdatesTapped)
            } label: {
                Label("检查更新…", systemImage: "arrow.triangle.2.circlepath")
            }

            Link(destination: URL(string: "https://github.com/ygsgdbd/V2Bar")!) {
                Label("GitHub 仓库", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Button {
                store.send(.quitTapped)
            } label: {
                Label("退出 V2Bar", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
    }

    static func isRootMenuTrackingNotification(_ notification: Notification) -> Bool {
        guard let menu = notification.object as? NSMenu else { return false }
        return menu.supermenu == nil && menu !== NSApp.mainMenu
    }

    @ViewBuilder
    private var accountSection: some View {
        if let profile = store.profile {
            Menu {
                Text("加入于 \(Date(timeIntervalSince1970: TimeInterval(profile.created)), format: .dateTime.year().month().day())")
                Divider()
                if let url = profile.profileURL {
                    Link(destination: url) {
                        Label("V2EX 个人主页", systemImage: "person.crop.circle")
                    }
                }
                if let url = profile.websiteURL {
                    Link(destination: url) { Label("Website", systemImage: "globe") }
                }
                if let url = profile.githubURL {
                    Link(destination: url) { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                }
                if let url = profile.twitterURL {
                    Link(destination: url) { Label("Twitter", systemImage: "at") }
                }
            } label: {
                ProfileIcon(data: store.avatarData)
                Text(profile.username)
                accountRefreshStatusLabel
            }
        } else if store.hasToken {
            Label(store.isRefreshing ? "正在加载个人资料…" : "暂无个人资料", systemImage: "person.crop.circle")
        } else {
            Label("请先设置 V2EX Token", systemImage: "person.crop.circle.badge.questionmark")
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        if store.recentNotifications.isEmpty {
            Text(store.isRefreshing ? "正在获取最近通知…" : "暂无最近通知")
        } else {
            Section("最近通知") {
                ForEach(store.recentNotifications) { notification in
                    Menu {
                        Text(notification.plainText)
                        if let topicURL = notification.topicURL {
                            Button {
                                store.send(.openURLTapped(topicURL))
                            } label: {
                                Label("打开主题", systemImage: "safari")
                            }
                        }
                        if let memberURL = URL(string: "https://www.v2ex.com/member/\(notification.member.username)") {
                            Button {
                                store.send(.openURLTapped(memberURL))
                            } label: {
                                Label("查看用户", systemImage: "person")
                            }
                        }
                    } label: {
                        Image(systemName: notification.kind.systemImage)
                        Text(notification.menuTitle)
                            .lineLimit(1)
                        if let topicTitle = notification.topicTitle {
                            Text("\(topicTitle) · @\(notification.member.username) · \(notification.createdDate, style: .relative)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else {
                            Text("@\(notification.member.username) · \(notification.createdDate, style: .relative)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accountRefreshStatusLabel: some View {
        switch store.accountRefreshStatus {
        case .refreshing:
            Text("正在刷新…")
        case let .updated(date):
            Text("更新于 \(date, style: .relative)")
                .monospacedDigit()
        case .notUpdated:
            Text("尚未刷新")
        }
    }

    @ViewBuilder
    private var tokenMenu: some View {
        if store.hasToken {
            Menu {
                Text("Token：\(store.maskedToken)")
                if let expirationDate = store.tokenInfo?.expirationDate {
                    Text("有效期：\(expirationDate, style: .relative)")
                }

                Button {
                    store.send(.tokenEditTapped)
                } label: {
                    Label("更换 Token", systemImage: "key")
                }

                Link(destination: URL(string: "https://www.v2ex.com/settings/tokens")!) {
                    Label("管理 Token", systemImage: "safari")
                }

                Button(role: .destructive) {
                    store.send(.logoutTapped)
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Label(
                    store.isValidatingToken ? "正在验证 Token…" : "Token 配置",
                    systemImage: "key"
                )
            }
        } else {
            Button {
                store.send(.tokenEditTapped)
            } label: {
                Label(
                    store.isValidatingToken ? "正在验证 Token…" : "设置 Token",
                    systemImage: "key"
                )
            }
            .disabled(store.isValidatingToken)
        }
    }

    @ViewBuilder
    private var v2exLinks: some View {
        Link(destination: URL(string: "https://www.v2ex.com/")!) {
            Label("V2EX 首页", systemImage: "house")
        }
        Link(destination: URL(string: "https://www.v2ex.com/t")!) {
            Label("时间轴", systemImage: "clock")
        }
        Link(destination: URL(string: "https://www.v2ex.com/new/create")!) {
            Label("创建主题", systemImage: "square.and.pencil")
        }
        Link(destination: URL(string: "https://www.v2ex.com/notifications")!) {
            Label("消息中心", systemImage: "bell")
        }
        Link(destination: URL(string: "https://www.v2ex.com/settings")!) {
            Label("个人设置", systemImage: "gearshape")
        }
    }

    @ViewBuilder
    private var autoRefreshControls: some View {
        Menu {
            ForEach(AutoRefreshMode.allCases) { mode in
                Button {
                    store.send(.autoRefreshModeTapped(mode))
                } label: {
                    if store.autoRefreshMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            Label("自动刷新：\(store.autoRefreshMode.title)", systemImage: "clock.arrow.circlepath")
        }
    }

    @ViewBuilder
    private var launchAtLoginControls: some View {
        Toggle(
            "登录时启动",
            isOn: Binding(
                get: { store.launchAtLoginEnabled },
                set: { store.send(.launchAtLoginTapped($0)) }
            )
        )
        .toggleStyle(.checkbox)
        .disabled(store.isSettingLaunchAtLogin || store.isReadmeDemo)

        if store.launchAtLoginStatus == .requiresApproval {
            Text("请在系统设置 > 通用 > 登录项中批准 V2Bar。")
            Button {
                store.send(.openLoginItemsSettingsTapped)
            } label: {
                Label("打开登录项设置", systemImage: "gear")
            }
        }
    }
}

private struct ProfileIcon: View {
    let data: Data?

    var body: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 18, height: 18)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle")
        }
    }
}

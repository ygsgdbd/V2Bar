import SwiftUI
import SwifterSwift

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: Action
    
    enum Action {
        case url(String)
        case logout
    }
    
    static let allActions: [QuickAction] = [
        QuickAction(title: "时间轴", icon: "clock", action: .url("https://www.v2ex.com/t")),
        QuickAction(title: "创建主题", icon: "square.and.pencil", action: .url("https://www.v2ex.com/new/create")),
        QuickAction(title: "消息中心", icon: "bell", action: .url("https://www.v2ex.com/notifications")),
        QuickAction(title: "个人设置", icon: "gearshape", action: .url("https://www.v2ex.com/settings")),
        QuickAction(title: "退出登录", icon: "rectangle.portrait.and.arrow.right", action: .logout)
    ]
}

enum SocialLinkType {
    case website(URL)
    case github(URL)
    case twitter(URL)
    
    var title: String {
        switch self {
        case .website: return "WebSite"
        case .github: return "Github"
        case .twitter: return "Twitter"
        }
    }
    
    var icon: String {
        switch self {
        case .website: return "globe"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .twitter: return "bird"
        }
    }
    
    var url: URL {
        switch self {
        case .website(let url): return url
        case .github(let url): return url
        case .twitter(let url): return url
        }
    }
}

struct SocialLink: View {
    let type: SocialLinkType
    
    var body: some View {
        Link(destination: type.url) {
            HStack(spacing: 2) {
                Image(systemName: type.icon)
                Text(type.title)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        .buttonStyle(.link)
    }
}

struct UserProfileView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    @State private var isUsernameHovered = false
    
    var body: some View {
        Group {
            if let profile = viewModel.profileState.value {
                // 有缓存数据，直接显示
                profileContent(profile)
            } else if viewModel.profileState.isLoading {
                // 无缓存数据且正在加载
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if let error = viewModel.profileState.error {
                // 显示错误
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .task {
            await viewModel.fetchProfile()
        }
    }
    
    @ViewBuilder
    private func profileContent(_ profile: V2EXUserProfile) -> some View {
        VStack(spacing: 0) {
            // 用户信息
            VStack(spacing: 8) {
                // 头像和用户名区域
                HStack(spacing: 12) {
                    Link(destination: URL(string: profile.url)!) {
                        AsyncImage(url: profile.avatarLarge?.url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.link)
                    .focusable(false)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Link(destination: URL(string: profile.url)!) {
                                Text(profile.username)
                                    .usernameStyle(isHovered: $isUsernameHovered)
                            }
                            .buttonStyle(.link)
                            .onHover { hovering in
                                isUsernameHovered = hovering
                            }
                            
                            Spacer()
                            
                            Text("加入于 \(Date.fromUnixTimestamp(profile.created).formattedString)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 预留底部链接域
                        HStack(spacing: 8) {
                            if let websiteURL = profile.websiteURL {
                                SocialLink(type: .website(websiteURL))
                            }
                            
                            if let githubURL = profile.githubURL {
                                SocialLink(type: .github(githubURL))
                            }
                            
                            if let twitterURL = profile.twitterURL {
                                SocialLink(type: .twitter(twitterURL))
                            }
                        }
                    }
                }
                
                
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
            
            // 快速操作
            HStack(spacing: 0) {
                ForEach(Array(QuickAction.allActions.enumerated()), id: \.element.id) { index, action in
                    Button {
                        switch action.action {
                        case .url(let urlString):
                            NSWorkspace.shared.open(URL(string: urlString)!)
                            NSApplication.shared.hide(nil)
                        case .logout:
                            Task { await viewModel.clearToken() }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.system(size: 14))
                            Text(action.title)
                                .font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HoverButtonStyle())
                    
                    if index < QuickAction.allActions.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
} 

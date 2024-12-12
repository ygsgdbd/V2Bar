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

struct UserProfileView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    
    var body: some View {
        Group {
            if let profile = viewModel.profile {
                // 有缓存数据，直接显示
                profileContent(profile)
            } else if viewModel.isProfileLoading {
                // 无缓存数据且正在加载
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if let error = viewModel.profileError {
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
                }
                .buttonStyle(.plain)
                .pointingCursor
                
                VStack(alignment: .leading, spacing: 4) {
                    Link(destination: URL(string: profile.url)!) {
                        Text(profile.username)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .pointingCursor
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text("加入于 \(Date.fromUnixTimestamp(profile.created).formattedString)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        if let website = profile.website, let websiteUrl = URL(string: website) {
                            Link(destination: websiteUrl) {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Website")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .pointingCursor
                        }
                        
                        if let github = profile.github {
                            Link(destination: URL(string: "https://github.com/\(github)")!) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("GitHub")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .pointingCursor
                        }
                    }
                }
                
                Spacer()
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
                        case .logout:
                            Task { await viewModel.clearToken() }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: action.icon)
                                .font(.system(size: 14))
                            Text(action.title)
                                .font(.system(size: 11))
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

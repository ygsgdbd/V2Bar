import SwiftUI
import SwifterSwift

struct NotificationsView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    @State private var hoveredNotificationId: Int?
    
    var body: some View {
        Group {
            if !viewModel.notificationsState.value.isEmpty {
                // 有缓存数据，直接显示列表
                notificationsList
            } else if viewModel.notificationsState.isLoading {
                // 无缓存数据且正在加载
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if let error = viewModel.notificationsState.error {
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
            } else {
                // 无缓存数据且加载完成（空列表）
                Text("暂无通知")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .task {
            await viewModel.fetchNotifications()
        }
    }
    
    private var notificationsList: some View {
        List(viewModel.notificationsState.value.enumerated().map { $0 }, id: \.element.id) { index, notification in
            NotificationRow(notification: notification, index: index + 1)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(hoveredNotificationId == notification.id ? Color.gray.opacity(0.1) : Color.clear)
                )
                .onHover { isHovered in
                    hoveredNotificationId = isHovered ? notification.id : nil
                }
                .onTapGesture {
                    if let topicLink = notification.links.first(where: { $0.url.path.hasPrefix("/t/") }) {
                        NSWorkspace.shared.open(topicLink.url)
                    }
                }
                .pointingCursor
        }
        .listStyle(.plain)
    }
}

struct NotificationRow: View {
    let notification: V2EXNotification
    let index: Int
    @State private var isUsernameHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 通知标题
            HStack(alignment: .center, spacing: 6) {
                Link(destination: URL(string: "https://v2ex.com/member/\(notification.member.username)")!) {
                    HStack(spacing: 0) {
                        Image(systemName: "at")
                            .foregroundColor(.secondary.opacity(0.8))
                            .font(.caption2)
                        Text(notification.member.username)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .underline(isUsernameHovered)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isUsernameHovered = hovering
                }
                .pointingCursor
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(Date.fromUnixTimestamp(notification.created).relativeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("#\(index)")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .monospacedDigit()
            }
            
            // 通知内容
            Text(notification.plainText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(4)
            
            // 回复内容
            if let payload = notification.payload, !payload.isWhitespace {
                Text(payload)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 2)
                            .padding(.vertical, 4),
                        alignment: .leading
                    )
            }
        }
        .padding(.vertical, 6)
    }
} 

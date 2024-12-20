import SwiftUI
import SwifterSwift

struct NotificationsView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    @State private var hoveredNotificationId: Int?
    
    var body: some View {
        LoadableView(
            state: viewModel.notificationsState,
            emptyText: "暂无通知",
            isEmpty: { $0.isEmpty }
        ) { notifications in
            notificationsList(notifications)
        }
    }
    
    private func notificationsList(_ notifications: [V2EXNotification]) -> some View {
        List(notifications.enumerated().map { $0 }, id: \.element.id) { index, notification in
            NotificationRow(notification: notification, index: index + 1)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(hoveredNotificationId == notification.id ? Color.gray.opacity(0.1) : Color.clear)
                )
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color.secondary.opacity(0.1))
                .onHover { isHovered in
                    hoveredNotificationId = isHovered ? notification.id : nil
                }
                .onTapGesture {
                    if let topicLink = notification.links.first(where: { $0.url.path.hasPrefix("/t/") }) {
                        NSWorkspace.shared.open(topicLink.url)
                    }
                }
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
                            .usernameStyle(isHovered: $isUsernameHovered)
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

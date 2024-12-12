import SwiftUI
import SwifterSwift

struct NotificationsView: View {
    @State private var notifications: [Notification] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var hoveredNotificationId: Int?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } else if notifications.isEmpty {
                Text("暂无通知")
                    .foregroundColor(.secondary)
            } else {
                List(notifications) { notification in
                    NotificationRow(notification: notification)
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
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
            }
        }
        .task {
            await fetchNotifications()
        }
    }
    
    private func fetchNotifications() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await V2EXService.shared.fetchNotifications()
            let response = try JSONDecoder().decode(V2EXResponse<[Notification]>.self, from: data)
            await MainActor.run {
                self.notifications = response.result
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.notifications = []
            }
        }
    }
}

struct NotificationRow: View {
    let notification: Notification
    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        return formatter
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // 通知标题
                HStack(alignment: .center, spacing: 6) {
                    Text(notification.member.username)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(Self.dateFormatter.localizedString(for: Date(timeIntervalSince1970: TimeInterval(notification.created)), relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 通知内容
                Text(notification.plainText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                // 回复内容
                if let payload = notification.payload, !payload.isWhitespace {
                    Text(payload)
                        .font(.callout)
                        .foregroundColor(.secondary)
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
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
} 

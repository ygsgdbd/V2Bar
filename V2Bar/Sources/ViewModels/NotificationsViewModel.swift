import SwiftUI

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [Notification] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    func fetchNotifications() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await V2EXService.shared.fetchNotifications()
            let response = try JSONDecoder().decode(V2EXResponse<[Notification]>.self, from: data)
            self.notifications = response.result
            self.error = nil
        } catch {
            self.error = error
            self.notifications = []
        }
    }
} 
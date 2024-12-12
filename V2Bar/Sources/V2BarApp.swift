import SwiftUI

@main
struct V2BarApp: App {
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @StateObject private var userProfileViewModel = UserProfileViewModel()
    
    var body: some Scene {
        MenuBarExtra("V2Bar", systemImage: "network") {
            ContentView()
                .environmentObject(notificationsViewModel)
                .environmentObject(userProfileViewModel)
        }
        .menuBarExtraStyle(.window)
    }
} 
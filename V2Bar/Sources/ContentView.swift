import SwiftUI
import SwiftUIX

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            UserProfileView()
                .height(80)
            
            Divider()
            
            NotificationsView()
                .maxHeight(.infinity)
                .minHeight(300)
            
            SettingsView()
        }
        .width(360)
        .minHeight(600)
    }
}

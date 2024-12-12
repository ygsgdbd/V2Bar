import SwiftUI

@main
struct V2BarApp: App {
    var body: some Scene {
        MenuBarExtra("V2Bar", systemImage: "network") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
} 
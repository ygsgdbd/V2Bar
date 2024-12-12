import SwiftUI

@main
struct V2BarApp: App {
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Text("V2")
                .font(.custom("Futura", size: 12))
                .fontWeight(.medium)
        }
        .menuBarExtraStyle(.window)
    }
} 

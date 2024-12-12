import SwiftUI
import SwifterSwift

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    NSApplication.shared.hide(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
} 

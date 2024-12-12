import SwiftUI
import AppKit

struct BottomButtonsView: View {
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
} 
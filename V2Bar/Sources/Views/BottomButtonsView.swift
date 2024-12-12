import SwiftUI
import AppKit

struct BottomButtonsView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            Button("刷新 (⌘R)") {
                Task {
                    await viewModel.refreshAll()
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .keyboardShortcut("r", modifiers: .command)
            
            Spacer()
            
            Button("退出 (⌘Q)") {
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

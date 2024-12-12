import SwiftUI
import SwifterSwift

struct QuickLink: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let iconName: String
}

struct QuickLinksView: View {
    private var links: [QuickLink] {
        [
            QuickLink(
                title: "V2EX 首页",
                url: URL(string: "https://www.v2ex.com/")!,
                iconName: "house"
            ),
            QuickLink(
                title: "关于 V2Bar",
                url: URL(string: "https://github.com/ygsgdbd/V2Bar")!,
                iconName: "info.circle"
            )
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                Button {
                    NSWorkspace.shared.open(link.url)
                    NSApplication.shared.hide(nil)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: link.iconName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 16, alignment: .center)
                        Text(link.title)
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButtonStyle())
                
                if index < links.count - 1 {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
    }
} 

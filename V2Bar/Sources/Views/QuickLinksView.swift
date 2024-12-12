import SwiftUI

struct QuickLink: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let iconName: String
}

struct QuickLinksView: View {
    private let links = [
        QuickLink(
            title: "V2EX 首页",
            url: URL(string: "https://www.v2ex.com/")!,
            iconName: "house"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                Button {
                    NSWorkspace.shared.open(link.url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: link.iconName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
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

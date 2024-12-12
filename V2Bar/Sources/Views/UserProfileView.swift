import SwiftUI
import SwifterSwift
import SwiftUIX

struct UserProfileView: View {
    let profile: V2EXUserProfile.UserInfo
    @State private var isAvatarHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Link(destination: URL(string: profile.url)!) {
                AsyncImage(url: profile.avatarLarge?.url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accentColor.opacity(isAvatarHovered ? 0.5 : 0), lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.2), value: isAvatarHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isAvatarHovered = hovering
            }
            .pointingCursor
            
            VStack(alignment: .leading, spacing: 4) {
                Link(destination: URL(string: profile.url)!) {
                    Text(profile.username)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .pointingCursor
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("加入于 \(Date.fromUnixTimestamp(profile.created).formattedString)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    if let website = profile.website, let websiteUrl = URL(string: website) {
                        Link(destination: websiteUrl) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Website")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .pointingCursor
                    }
                    
                    if let github = profile.github {
                        Link(destination: URL(string: "https://github.com/\(github)")!) {
                            HStack {
                                Image(systemName: "link")
                                Text("GitHub")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .pointingCursor
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(height: 80)
    }
} 

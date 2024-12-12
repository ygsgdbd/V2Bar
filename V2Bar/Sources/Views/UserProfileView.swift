import SwiftUI
import SwifterSwift

struct UserProfileView: View {
    let profile: V2EXUserProfile.UserInfo
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: profile.avatarLarge?.url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.username)
                    .font(.headline)
                
                if let github = profile.github {
                    Link(destination: URL(string: "https://github.com/\(github)")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
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

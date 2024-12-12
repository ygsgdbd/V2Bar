import SwiftUI
import SwifterSwift

struct UserProfileView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    @State private var isAvatarHovered = false
    
    var body: some View {
        Group {
            if viewModel.isProfileLoading {
                ProgressView()
                    .frame(height: 80)
            } else if let error = viewModel.profileError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 80)
            } else if let profile = viewModel.profile {
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
                    }
                    .buttonStyle(.plain)
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
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("未登录")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(height: 80)
            }
        }
        .task {
            if viewModel.profile == nil {
                await viewModel.fetchProfile()
            }
        }
    }
} 

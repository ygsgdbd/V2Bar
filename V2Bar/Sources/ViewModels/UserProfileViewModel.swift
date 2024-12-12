import SwiftUI

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published private(set) var profile: V2EXUserProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    func fetchProfile() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await V2EXService.shared.fetchMemberProfile()
            let response = try JSONDecoder().decode(V2EXResponse<V2EXUserProfile>.self, from: data)
            self.profile = response.result
            self.error = nil
        } catch {
            print("Failed to fetch profile: \(error)")
            self.error = error
            self.profile = nil
        }
    }
} 
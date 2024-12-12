import Foundation

extension V2EXTokenInfo {
    var formattedExpirationText: String {
        if expiration <= 0 {
            return "(已过期)"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        let date = Date(timeIntervalSinceNow: TimeInterval(expiration))
        let relativeTime = formatter.localizedString(for: date, relativeTo: Date())
            .replacingOccurrences(of: "后", with: "后过期")
        
        return "(\(relativeTime))"
    }
} 
import Foundation

extension DateFormatter {
    static let v2exDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension RelativeDateTimeFormatter {
    static let shared: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        return formatter
    }()
}

extension Date {
    static func fromUnixTimestamp(_ timestamp: Int) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
    
    var formattedString: String {
        return DateFormatter.v2exDateFormatter.string(from: self)
    }
    
    var relativeString: String {
        return RelativeDateTimeFormatter.shared.localizedString(for: self, relativeTo: Date())
    }
} 
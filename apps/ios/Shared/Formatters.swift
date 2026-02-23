import Foundation

// MARK: - Price Formatting

/// Format price_cents (원 단위 정수) → "15,000원"
func formatPrice(_ cents: Int) -> String {
    let krwFormatter = NumberFormatter()
    krwFormatter.numberStyle = .decimal
    krwFormatter.groupingSeparator = ","
    krwFormatter.maximumFractionDigits = 0
    let formatted = krwFormatter.string(from: NSNumber(value: cents)) ?? "\(cents)"
    return "\(formatted)원"
}

// MARK: - Relative Time

/// Parse ISO 8601 string → Date
private func parseISO(_ isoString: String) -> Date? {
    let iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let iso8601FallbackFormatter = ISO8601DateFormatter()
    iso8601FallbackFormatter.formatOptions = [.withInternetDateTime]

    return iso8601Formatter.date(from: isoString)
        ?? iso8601FallbackFormatter.date(from: isoString)
}

/// Convert ISO 8601 date string → relative time string
/// "방금 전", "3분 전", "2시간 전", "어제", "3일 전", "2025.01.15"
func relativeTime(from isoString: String) -> String {
    guard let date = parseISO(isoString) else { return isoString }
    let now = Date()
    let seconds = Int(now.timeIntervalSince(date))

    if seconds < 60 {
        return "방금 전"
    }
    let minutes = seconds / 60
    if minutes < 60 {
        return "\(minutes)분 전"
    }
    let hours = minutes / 60
    if hours < 24 {
        return "\(hours)시간 전"
    }
    let days = hours / 24
    if days == 1 {
        return "어제"
    }
    if days < 30 {
        return "\(days)일 전"
    }
    let absoluteDateFormatter = DateFormatter()
    absoluteDateFormatter.dateFormat = "yyyy.MM.dd"
    return absoluteDateFormatter.string(from: date)
}

/// Format time-only (HH:mm) from ISO 8601 string for chat timestamps
func formatTime(from isoString: String) -> String {
    guard let date = parseISO(isoString) else { return "" }
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

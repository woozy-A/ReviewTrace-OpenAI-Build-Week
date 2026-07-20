import Foundation

enum ReviewTimeFormatter {
    static func clock(_ seconds: TimeInterval) -> String {
        let safeSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = safeSeconds / 60
        let remainder = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    static func markdownDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func srtTimestamp(_ seconds: TimeInterval) -> String {
        timestamp(seconds, millisecondSeparator: ",")
    }

    static func vttTimestamp(_ seconds: TimeInterval) -> String {
        timestamp(seconds, millisecondSeparator: ".")
    }

    private static func timestamp(_ seconds: TimeInterval, millisecondSeparator: String) -> String {
        let milliseconds = max(0, Int((seconds * 1000).rounded()))
        let hours = milliseconds / 3_600_000
        let minutes = (milliseconds % 3_600_000) / 60_000
        let secs = (milliseconds % 60_000) / 1000
        let millis = milliseconds % 1000
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, millisecondSeparator, millis)
    }
}

import Foundation

func formatDate(_ date: Date, format: String = "yyyy.MM.dd") -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    return formatter.string(from: date)
}

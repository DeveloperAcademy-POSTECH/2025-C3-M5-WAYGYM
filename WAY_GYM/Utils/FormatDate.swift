import Foundation

// yyyy.mm.dd로 출력
func formatDate(_ date: Date, format: String = "yyyy.MM.dd") -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    return formatter.string(from: date)
}

// yy.mm.dd로 출력
func formatShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yy.MM.dd"
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    return formatter.string(from: date)
}

// 정수로 출력
func formatNumber(_ number: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal // 쉼표 (0,000,000 형태)
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: number)) ?? "0"
}

// 소수점 둘째까지 출력
func formatDecimal(_ number: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2    // 소수점 최소 2자리
    formatter.maximumFractionDigits = 2    // 소수점 최대 2자리
    return formatter.string(from: NSNumber(value: number)) ?? "0.00"
}

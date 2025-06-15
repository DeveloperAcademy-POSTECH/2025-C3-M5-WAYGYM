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
    formatter.maximumFractionDigits = 0 // 소수점 없음, 정수 형태
    return formatter.string(from: NSNumber(value: number)) ?? "0"
}

func formatToDecimal1(_ number: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal // 쉼표
    formatter.maximumFractionDigits = 1 // 소수점 최대 한자리. 정수면 소수점 없음
    return formatter.string(from: NSNumber(value: number)) ?? "0"
}

func formatDecimal(_ number: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal         // 쉼표 포함 숫자 스타일
    formatter.minimumFractionDigits = 2     // 소수점 최소 2자리
    formatter.maximumFractionDigits = 2     // 소수점 최대 2자리
    return formatter.string(from: NSNumber(value: number)) ?? "0.00"
}

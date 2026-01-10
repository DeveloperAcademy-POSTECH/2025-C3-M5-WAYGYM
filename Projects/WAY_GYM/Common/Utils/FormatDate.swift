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
func formatDecimal2(_ number: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal         // 쉼표 포함 숫자 스타일
    formatter.minimumFractionDigits = 2     // 소수점 최소 2자리
    formatter.maximumFractionDigits = 2     // 소수점 최대 2자리
    return formatter.string(from: NSNumber(value: number)) ?? "0.00"
}

// 런닝 결과 화면 - 두 시각의 차이를 계산해서 분 단위로 반환
//func formatDuration(from start: Date, to end: Date) -> String {
//    let interval = end.timeIntervalSince(start)
//    let minutes = Int(interval / 60)
//    return "\(minutes)분"
//}

func formatDuration(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: duration) ?? "00:00:00"
}

extension Date {
    // MARK: - Cached formatters (Asia/Seoul)
    private static let _seoulTZ = TimeZone(identifier: "Asia/Seoul")

    private static let _fmtYMDHM: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm"
        f.timeZone = _seoulTZ
        return f
    }()

    private static let _fmtYMD: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        f.timeZone = _seoulTZ
        return f
    }()

    private static let _fmtHM: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = _seoulTZ
        return f
    }()

    private static let _fmtMediumShortKR: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = _seoulTZ
        return f
    }()

    /// yyyy.MM.dd HH:mm
    func formattedDate() -> String {
        return Date._fmtYMDHM.string(from: self)
    }

    /// yyyy.MM.dd
    func formattedYMD() -> String {
        return Date._fmtYMD.string(from: self)
    }

    /// HH:mm
    func formattedHM() -> String {
        return Date._fmtHM.string(from: self)
    }

    /// Medium date style + short time style (Korean locale)
    func formattedMediumShortKR() -> String {
        return Date._fmtMediumShortKR.string(from: self)
    }

    /// 일~토 (Korean weekday symbol)
    func koreanWeekday() -> String {
        let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
        let calendar = Calendar(identifier: .gregorian)
        let idx = calendar.component(.weekday, from: self) - 1
        return weekdaySymbols[idx]
    }
}

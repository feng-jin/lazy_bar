import Foundation

struct QuoteRefreshScheduler {
    private enum Policy {
        static let activeMarketIntervalNanoseconds: UInt64 = 3_000_000_000
        static let inactiveMarketIntervalNanoseconds: UInt64 = 600_000_000_000
        static let tradingDays: Set<Int> = [2, 3, 4, 5, 6]
        static let morningSessionStartHour = 9
        static let morningSessionStartMinute = 30
        static let morningSessionEndHour = 11
        static let morningSessionEndMinute = 30
        static let afternoonSessionStartHour = 13
        static let afternoonSessionStartMinute = 0
        static let afternoonSessionEndHour = 15
        static let afternoonSessionEndMinute = 0
    }

    private let calendar: Calendar

    init(calendar: Calendar = Self.marketCalendar) {
        self.calendar = calendar
    }

    func delayNanoseconds(referenceDate: Date = Date()) -> UInt64 {
        if isDuringTradingSession(at: referenceDate) {
            return Policy.activeMarketIntervalNanoseconds
        }

        let inactiveInterval = Policy.inactiveMarketIntervalNanoseconds
        guard let nextBoundary = nextTradingSessionStart(after: referenceDate) else {
            return inactiveInterval
        }

        let secondsUntilBoundary = max(0, nextBoundary.timeIntervalSince(referenceDate))
        let nanosecondsUntilBoundary = UInt64(secondsUntilBoundary * 1_000_000_000)
        return min(inactiveInterval, nanosecondsUntilBoundary)
    }

    private func isDuringTradingSession(at date: Date) -> Bool {
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard
            let weekday = components.weekday,
            Policy.tradingDays.contains(weekday),
            let hour = components.hour,
            let minute = components.minute
        else {
            return false
        }

        let minuteOfDay = hour * 60 + minute
        let morningStart = Policy.morningSessionStartHour * 60 + Policy.morningSessionStartMinute
        let morningEnd = Policy.morningSessionEndHour * 60 + Policy.morningSessionEndMinute
        let afternoonStart = Policy.afternoonSessionStartHour * 60 + Policy.afternoonSessionStartMinute
        let afternoonEnd = Policy.afternoonSessionEndHour * 60 + Policy.afternoonSessionEndMinute

        return (morningStart..<morningEnd).contains(minuteOfDay)
            || (afternoonStart..<afternoonEnd).contains(minuteOfDay)
    }

    private func nextTradingSessionStart(after date: Date) -> Date? {
        let referenceDayStart = calendar.startOfDay(for: date)

        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: referenceDayStart) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            guard Policy.tradingDays.contains(weekday) else {
                continue
            }

            let sessionStarts = [
                calendar.date(
                    bySettingHour: Policy.morningSessionStartHour,
                    minute: Policy.morningSessionStartMinute,
                    second: 0,
                    of: day
                ),
                calendar.date(
                    bySettingHour: Policy.afternoonSessionStartHour,
                    minute: Policy.afternoonSessionStartMinute,
                    second: 0,
                    of: day
                )
            ]

            if let nextStart = sessionStarts
                .compactMap({ $0 })
                .first(where: { $0 > date })
            {
                return nextStart
            }
        }

        return nil
    }

    private static let marketCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }()
}

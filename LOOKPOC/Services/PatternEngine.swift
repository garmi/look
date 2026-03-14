import Foundation

enum PatternRiskTier: String {
    case green
    case amber
    case red
}

struct PatternSnapshot {
    let medicationStreak: Int
    let adherenceCountLast7: Int
    let supportFlagsLast7: Int
    let averageTrialScoreLast7: Double?
    let riskTier: PatternRiskTier
    let summary: String
    let recommendedAction: String

    static let empty = PatternSnapshot(
        medicationStreak: 0,
        adherenceCountLast7: 0,
        supportFlagsLast7: 0,
        averageTrialScoreLast7: nil,
        riskTier: .green,
        summary: "Pattern engine activates after your first logs.",
        recommendedAction: "Log one medication confirmation and one check-in today."
    )
}

enum PatternEngine {
    static func analyze(
        healthLogs: [DailyHealthLog],
        trials: [DailyTrial],
        now: Date = .now
    ) -> PatternSnapshot {
        let recentHealthLogs = healthLogsLast7Days(healthLogs, now: now)
        let adherenceCount = recentHealthLogs.filter { $0.medicationConfirmedAt != nil }.count
        let supportFlags = recentHealthLogs.filter {
            $0.checkinStatus == .unsure || $0.checkinStatus == .help
        }.count
        let streak = medicationStreak(from: healthLogs, now: now)
        let recentTrials = trialsLast7Days(trials, now: now)
        let averageTrialScore = recentTrials.isEmpty
            ? nil
            : recentTrials.map(\.rating).reduce(0, +).doubleValue / Double(recentTrials.count)

        let riskTier: PatternRiskTier
        if recentHealthLogs.contains(where: { $0.checkinStatus == .help }) || adherenceCount <= 2 {
            riskTier = .red
        } else if supportFlags > 0 || adherenceCount <= 5 {
            riskTier = .amber
        } else {
            riskTier = .green
        }

        let summary: String
        if recentHealthLogs.isEmpty && recentTrials.isEmpty {
            summary = "Pattern engine activates after your first logs."
        } else if let averageTrialScore {
            summary = "\(adherenceCount)/7 meds confirmed · \(supportFlags) support flags · avg trial \(String(format: "%.1f", averageTrialScore))/5."
        } else {
            summary = "\(adherenceCount)/7 meds confirmed · \(supportFlags) support flags."
        }

        let recommendedAction: String
        switch riskTier {
        case .green:
            recommendedAction = streak >= 7
                ? "Consistency is strong. Keep the streak and capture questions early."
                : "Consistency is building. Confirm medication and log one question today."
        case .amber:
            recommendedAction = "Check in with your transplant coordinator and review missed routine steps."
        case .red:
            recommendedAction = "Treat this as a higher-risk pattern. Contact your doctor or hospital support team today."
        }

        return PatternSnapshot(
            medicationStreak: streak,
            adherenceCountLast7: adherenceCount,
            supportFlagsLast7: supportFlags,
            averageTrialScoreLast7: averageTrialScore,
            riskTier: riskTier,
            summary: summary,
            recommendedAction: recommendedAction
        )
    }

    private static func healthLogsLast7Days(_ logs: [DailyHealthLog], now: Date) -> [DailyHealthLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) else {
            return []
        }

        return logs.filter { log in
            guard let date = dayKeyDateFormatter.date(from: log.dayKey) else { return false }
            return date >= sevenDaysAgo && date <= today
        }
    }

    private static func trialsLast7Days(_ trials: [DailyTrial], now: Date) -> [DailyTrial] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) else {
            return []
        }

        return trials.filter { trial in
            let day = calendar.startOfDay(for: trial.createdAt)
            return day >= sevenDaysAgo && day <= today
        }
    }

    private static func medicationStreak(from logs: [DailyHealthLog], now: Date) -> Int {
        let calendar = Calendar.current
        let confirmedDays = Set(
            logs.compactMap { log -> Date? in
                guard log.medicationConfirmedAt != nil else { return nil }
                return dayKeyDateFormatter.date(from: log.dayKey)
            }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        while confirmedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    private static let dayKeyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension Int {
    var doubleValue: Double { Double(self) }
}

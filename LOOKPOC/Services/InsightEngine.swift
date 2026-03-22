import Foundation

struct InsightPoint: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let value: Double
}

struct InsightMetricSeries: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let status: String
    let points: [InsightPoint]
}

struct InsightSnapshot {
    let rangeDays: Int
    let medicationSeries: [InsightPoint]
    let checkinSeries: [InsightPoint]
    let trialSeries: [InsightPoint]
    let questionSeries: [InsightPoint]
    let labSeries: [InsightMetricSeries]
    let patientHeadline: String
    let patientBody: String
    let doctorHeadline: String
    let doctorBody: String
    let highlights: [String]

    static let empty = InsightSnapshot(
        rangeDays: 7,
        medicationSeries: [],
        checkinSeries: [],
        trialSeries: [],
        questionSeries: [],
        labSeries: [],
        patientHeadline: "Insights appear after a few days of real use.",
        patientBody: "Confirm medication, complete a daily check-in, and upload one report to unlock a clearer pattern story.",
        doctorHeadline: "Doctor insights appear when trend data exists.",
        doctorBody: "LOOK will summarize adherence, symptoms, questions, and labs once enough records accumulate.",
        highlights: []
    )
}

enum InsightsRange: Int, CaseIterable, Identifiable {
    case seven = 7
    case fourteen = 14
    case thirty = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .seven:
            return "7D"
        case .fourteen:
            return "14D"
        case .thirty:
            return "30D"
        }
    }
}

enum InsightEngine {
    static func buildSnapshot(
        range: InsightsRange,
        profile: UserProfile?,
        questions: [QuestionEntry],
        trials: [DailyTrial],
        healthLogs: [DailyHealthLog],
        records: [StoredHealthRecord],
        now: Date = .now
    ) -> InsightSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today) ?? today
        let dates = (0..<range.rawValue).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }

        let logsByDay = Dictionary(uniqueKeysWithValues: healthLogs.compactMap { log -> (Date, DailyHealthLog)? in
            guard let date = dayKeyDateFormatter.date(from: log.dayKey) else { return nil }
            return (calendar.startOfDay(for: date), log)
        })

        let structuredTrials = trials.map(decodeTrial)
        let groupedTrials = Dictionary(grouping: structuredTrials) { calendar.startOfDay(for: $0.logDate) }
        let groupedQuestions = Dictionary(grouping: questions) { calendar.startOfDay(for: $0.createdAt) }

        let medicationSeries = dates.map { date in
            let value = logsByDay[date]?.medicationConfirmedAt != nil ? 1.0 : 0.0
            return InsightPoint(date: date, label: axisLabel(for: date, range: range), value: value)
        }

        let checkinSeries = dates.map { date in
            let value: Double
            switch logsByDay[date]?.checkinStatus {
            case .allGood:
                value = 3
            case .unsure:
                value = 2
            case .help:
                value = 1
            case .none:
                value = 0
            }
            return InsightPoint(date: date, label: axisLabel(for: date, range: range), value: value)
        }

        let trialSeries = dates.map { date in
            let dayTrials = groupedTrials[date] ?? []
            let value: Double
            if dayTrials.isEmpty {
                value = 0
            } else {
                value = dayTrials.map(\.rating).reduce(0, +) / Double(dayTrials.count)
            }
            return InsightPoint(date: date, label: axisLabel(for: date, range: range), value: value)
        }

        let questionSeries = dates.map { date in
            let count = groupedQuestions[date]?.count ?? 0
            return InsightPoint(date: date, label: axisLabel(for: date, range: range), value: Double(count))
        }

        let filteredLabSeries = buildLabSeries(records: records, start: start)
        let pattern = PatternEngine.analyze(healthLogs: healthLogs, trials: trials, now: now)
        let careInsight = HealthRecordStore.buildInsights(
            profile: profile,
            pattern: pattern,
            records: records,
            questions: questions,
            trials: trials
        )
        let highlights = buildHighlights(
            profile: profile,
            pattern: pattern,
            labSeries: filteredLabSeries,
            questions: questions,
            trialSeries: trialSeries,
            questionSeries: questionSeries
        )

        return InsightSnapshot(
            rangeDays: range.rawValue,
            medicationSeries: medicationSeries,
            checkinSeries: checkinSeries,
            trialSeries: trialSeries,
            questionSeries: questionSeries,
            labSeries: filteredLabSeries,
            patientHeadline: careInsight.patientHeadline,
            patientBody: careInsight.patientBody,
            doctorHeadline: careInsight.doctorHeadline,
            doctorBody: careInsight.doctorBody,
            highlights: highlights
        )
    }

    private static func buildLabSeries(records: [StoredHealthRecord], start: Date) -> [InsightMetricSeries] {
        let bloodReports = records
            .filter { $0.type == .bloodReport && $0.capturedAt >= start }
            .sorted { $0.capturedAt < $1.capturedAt }

        let fallbackReports = records
            .filter { $0.type == .bloodReport }
            .sorted { $0.capturedAt < $1.capturedAt }

        let source = bloodReports.isEmpty ? fallbackReports : bloodReports
        guard !source.isEmpty else { return [] }

        let metrics = ["Creatinine", "eGFR", "Tacrolimus trough", "Potassium", "Haemoglobin", "HbA1c"]
        return metrics.compactMap { metric in
            let points = source.compactMap { record -> InsightPoint? in
                guard let value = record.values.first(where: { normalize($0.name) == normalize(metric) }),
                      let numeric = numericValue(from: value.value) else {
                    return nil
                }
                return InsightPoint(
                    date: record.capturedAt,
                    label: shortDateLabel(for: record.capturedAt),
                    value: numeric
                )
            }

            guard !points.isEmpty else { return nil }
            let latestRecord = source.last
            let latestValue = latestRecord?.values.first(where: { normalize($0.name) == normalize(metric) })
            let unit = latestValue?.unit ?? ""
            let status = latestValue?.status ?? "normal"
            let baseline = points.first?.value ?? points.last?.value ?? 0
            let latest = points.last?.value ?? 0
            let delta = latest - baseline
            let deltaWord: String
            if abs(delta) < 0.001 {
                deltaWord = "holding steady"
            } else {
                deltaWord = delta > 0 ? "up \(format(delta)) from baseline" : "down \(format(abs(delta))) from baseline"
            }

            return InsightMetricSeries(
                title: metric.replacingOccurrences(of: " trough", with: ""),
                subtitle: unit.isEmpty ? deltaWord : "\(unit) · \(deltaWord)",
                status: status,
                points: points
            )
        }
    }

    private static func buildHighlights(
        profile: UserProfile?,
        pattern: PatternSnapshot,
        labSeries: [InsightMetricSeries],
        questions: [QuestionEntry],
        trialSeries: [InsightPoint],
        questionSeries: [InsightPoint]
    ) -> [String] {
        var highlights: [String] = []

        highlights.append("\(profile?.name.isEmpty == false ? profile?.name ?? "Patient" : "Patient") is currently in a \(pattern.riskTier.rawValue) risk pattern with \(pattern.adherenceCountLast7)/7 medication confirmations.")

        if let lab = labSeries.first(where: { $0.status == "high" || $0.status == "low" }) {
            highlights.append("Latest lab focus: \(lab.title) is the strongest movement signal in the uploaded reports.")
        }

        let questionCount = Int(questionSeries.map(\.value).reduce(0, +))
        if questionCount > 0 {
            highlights.append("\(questionCount) question\(questionCount == 1 ? "" : "s") captured in the selected range. That is useful doctor-visit material, not noise.")
        }

        if let weakestTrial = trialSeries.filter({ $0.value > 0 }).min(by: { $0.value < $1.value }) {
            highlights.append("Lowest daily trial score in this window was \(format(weakestTrial.value))/5 on \(shortDateLabel(for: weakestTrial.date)).")
        }

        if let latestQuestion = questions.sorted(by: { $0.createdAt > $1.createdAt }).first {
            highlights.append("Most recent question theme: \(latestQuestion.question)")
        }

        return highlights.prefix(5).map { $0 }
    }

    private static func decodeTrial(_ trial: DailyTrial) -> DecodedTrial {
        if trial.nextImprovement.hasPrefix(trialPrefix) {
            let json = String(trial.nextImprovement.dropFirst(trialPrefix.count))
            if let data = json.data(using: .utf8),
               let payload = try? JSONDecoder().decode(TrialPayload.self, from: data) {
                return DecodedTrial(
                    logDate: payload.logDate,
                    rating: derivedRating(for: payload),
                    triageLevel: payload.triageLevel,
                    doctorNote: payload.doctorNote,
                    medicationConfirmed: payload.medicationConfirmed
                )
            }
        }

        return DecodedTrial(
            logDate: trial.createdAt,
            rating: trial.rating.doubleValue,
            triageLevel: fallbackTriage(for: trial.rating),
            doctorNote: trial.friction,
            medicationConfirmed: false
        )
    }

    private static func derivedRating(for payload: TrialPayload) -> Double {
        var score = 0
        score += payload.q1
        score += max(1, 5 - payload.q2)
        score += max(1, 5 - payload.q3)
        score += payload.q4

        switch payload.triageLevel {
        case "green":
            score += 4
        case "amber":
            score += 2
        default:
            break
        }

        return Double(min(max(Int(round(Double(score) / 4.2)), 1), 5))
    }

    private static func fallbackTriage(for rating: Int) -> String {
        switch rating {
        case 4...5:
            return "green"
        case 3:
            return "amber"
        default:
            return "red"
        }
    }

    private static func axisLabel(for date: Date, range: InsightsRange) -> String {
        range == .thirty ? shortDateLabel(for: date) : weekdayLabel(for: date)
    }

    private static func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private static func shortDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private static func numericValue(from raw: String) -> Double? {
        let filtered = raw.filter { "0123456789.".contains($0) }
        return Double(filtered)
    }

    private static func normalize(_ metric: String) -> String {
        metric.lowercased().replacingOccurrences(of: " ", with: "")
    }

    private static func format(_ value: Double) -> String {
        String(format: value.rounded() == value ? "%.0f" : "%.2f", value)
    }

    private static let dayKeyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let trialPrefix = "LOOK_TRIAL_V2|"
}

private struct DecodedTrial {
    let logDate: Date
    let rating: Double
    let triageLevel: String
    let doctorNote: String
    let medicationConfirmed: Bool
}

private struct TrialPayload: Codable {
    let triageLevel: String
    let q1: Int
    let q2: Int
    let q3: Int
    let q4: Int
    let doctorNote: String
    let medicationConfirmed: Bool
    let logDate: Date
}

private extension Int {
    var doubleValue: Double { Double(self) }
}

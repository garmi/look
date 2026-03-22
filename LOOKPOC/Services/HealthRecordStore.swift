import Foundation

enum StoredHealthRecordType: String, Codable {
    case bloodReport
    case prescription
}

struct StoredHealthValue: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var value: String
    var unit: String
    var status: String
    var lookNote: String
}

struct StoredHealthRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var type: StoredHealthRecordType
    var capturedAt: Date
    var sourceDateLabel: String
    var summary: String
    var flaggedValues: [String]
    var values: [StoredHealthValue]
}

struct HealthMetricTrend: Identifiable {
    var id = UUID()
    var metric: String
    var latestDisplay: String
    var baselineText: String
    var trendLine: String
    var status: String
    var series: [Double]
}

struct HealthRecordSnapshot {
    let totalRecords: Int
    let latestSummary: String
    let latestFlaggedValues: [String]
    let trendCards: [HealthMetricTrend]

    static let empty = HealthRecordSnapshot(
        totalRecords: 0,
        latestSummary: "Upload your first blood report to start learning your own baseline.",
        latestFlaggedValues: [],
        trendCards: []
    )
}

struct VisitPackSnapshot {
    let headline: String
    let previewLines: [String]
    let copyText: String

    static let empty = VisitPackSnapshot(
        headline: "Your doctor visit pack builds itself after you log questions, trials, and reports.",
        previewLines: [
            "Start with one uploaded blood report or one saved question.",
            "LOOK will turn that into a clinician-ready summary."
        ],
        copyText: ""
    )
}

struct CaregiverUpdateSnapshot {
    let preview: String
    let copyText: String

    static let empty = CaregiverUpdateSnapshot(
        preview: "Add a caregiver contact to generate a simple daily transplant update.",
        copyText: ""
    )
}

struct StageRoadmapSnapshot {
    let title: String
    let subtitle: String
    let actions: [String]
}

struct CareInsightSnapshot {
    let patientHeadline: String
    let patientBody: String
    let doctorHeadline: String
    let doctorBody: String

    static let empty = CareInsightSnapshot(
        patientHeadline: "Your insights will sharpen after a few days of real use.",
        patientBody: "Start with one medication confirmation, one daily log, and one uploaded report.",
        doctorHeadline: "Clinician synthesis appears after trend data is available.",
        doctorBody: "LOOK will summarise adherence, symptoms, labs, and key questions once records accumulate."
    )
}

struct WeeklyTrendSnapshot {
    let labels: [String]
    let medicationValues: [Double]
    let trialScores: [Double]
    let checkinScores: [Double]

    static let empty = WeeklyTrendSnapshot(labels: [], medicationValues: [], trialScores: [], checkinScores: [])
}

enum HealthRecordStore {
    static let recordsKey = "lookHealthRecords.v2"
    private static let legacyRecordsKey = "lookHealthRecords"

    static func loadRecords(defaults: UserDefaults = .standard) -> [StoredHealthRecord] {
        if let data = defaults.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([StoredHealthRecord].self, from: data) {
            return decoded.sorted { $0.capturedAt > $1.capturedAt }
        }

        let migrated = migrateLegacyRecords(defaults: defaults)
        if !migrated.isEmpty {
            saveRecords(migrated, defaults: defaults)
        }
        return migrated.sorted { $0.capturedAt > $1.capturedAt }
    }

    static func append(_ record: StoredHealthRecord, defaults: UserDefaults = .standard) {
        var records = loadRecords(defaults: defaults)
        records.insert(record, at: 0)
        saveRecords(records, defaults: defaults)
    }

    static func replaceAll(_ records: [StoredHealthRecord], defaults: UserDefaults = .standard) {
        saveRecords(records.sorted { $0.capturedAt > $1.capturedAt }, defaults: defaults)
    }

    static func makeRecord(
        type: StoredHealthRecordType,
        sourceDateLabel: String,
        summary: String,
        flaggedValues: [String],
        extractedValues: [ExtractedValue]
    ) -> StoredHealthRecord {
        StoredHealthRecord(
            type: type,
            capturedAt: .now,
            sourceDateLabel: sourceDateLabel,
            summary: summary,
            flaggedValues: flaggedValues,
            values: extractedValues.map {
                StoredHealthValue(
                    name: $0.name,
                    value: $0.value,
                    unit: $0.unit,
                    status: $0.status,
                    lookNote: $0.lookNote
                )
            }
        )
    }

    static func buildSnapshot(records: [StoredHealthRecord]) -> HealthRecordSnapshot {
        guard let latest = records.first else { return .empty }

        return HealthRecordSnapshot(
            totalRecords: records.count,
            latestSummary: latest.summary.isEmpty ? "Latest upload saved and ready for review." : latest.summary,
            latestFlaggedValues: latest.flaggedValues,
            trendCards: focusMetrics.compactMap { extractTrend(metric: $0, from: records) }
        )
    }

    static func buildVisitPack(
        profile: UserProfile?,
        questions: [QuestionEntry],
        trials: [DailyTrial],
        healthLogs: [DailyHealthLog],
        pattern: PatternSnapshot,
        records: [StoredHealthRecord]
    ) -> VisitPackSnapshot {
        guard !questions.isEmpty || !trials.isEmpty || !records.isEmpty || !healthLogs.isEmpty else {
            return .empty
        }

        let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false ? name! : "Patient")
        let recentQuestions = questions.prefix(3).map(\.question)
        let recentDoctorNotes = trials
            .prefix(3)
            .map(\.friction)
            .filter { !$0.isEmpty && $0 != "No doctor note" }
        let latestBloodReport = records.first(where: { $0.type == .bloodReport })

        var previewLines: [String] = []
        previewLines.append("Pattern: \(pattern.summary)")
        previewLines.append("Medication: \(pattern.adherenceCountLast7)/7 confirmations, streak \(pattern.medicationStreak) day(s)")

        if let latestBloodReport {
            let flagged = latestBloodReport.flaggedValues.prefix(3).joined(separator: ", ")
            previewLines.append(flagged.isEmpty ? "Latest labs: \(latestBloodReport.summary)" : "Flagged labs: \(flagged)")
        } else {
            previewLines.append("Latest labs: no uploaded blood report yet")
        }

        if let firstQuestion = recentQuestions.first {
            previewLines.append("Top doctor question: \(firstQuestion)")
        }

        if let firstNote = recentDoctorNotes.first {
            previewLines.append("Trial note: \(firstNote)")
        }

        var copyLines: [String] = []
        copyLines.append("LOOK Doctor Visit Pack")
        copyLines.append("Patient: \(displayName)")
        copyLines.append("Stage: \(profile?.stage.rawValue ?? "Not set")")
        copyLines.append("City: \(profile?.city.rawValue ?? "Not set")")
        copyLines.append("")
        copyLines.append("Pattern summary")
        copyLines.append("- \(pattern.summary)")
        copyLines.append("- \(pattern.recommendedAction)")
        copyLines.append("")

        if let latestBloodReport {
            copyLines.append("Latest uploaded report")
            copyLines.append("- \(latestBloodReport.sourceDateLabel)")
            copyLines.append("- \(latestBloodReport.summary)")
            if !latestBloodReport.flaggedValues.isEmpty {
                copyLines.append("- Discuss: \(latestBloodReport.flaggedValues.joined(separator: ", "))")
            }
            copyLines.append("")
        }

        if !recentQuestions.isEmpty {
            copyLines.append("Questions for doctor")
            recentQuestions.forEach { copyLines.append("- \($0)") }
            copyLines.append("")
        }

        if !recentDoctorNotes.isEmpty {
            copyLines.append("Recent notes")
            recentDoctorNotes.forEach { copyLines.append("- \($0)") }
        }

        return VisitPackSnapshot(
            headline: "Your next visit pack is ready to share or refine.",
            previewLines: previewLines,
            copyText: copyLines.joined(separator: "\n")
        )
    }

    static func buildCaregiverUpdate(
        profile: UserProfile?,
        pattern: PatternSnapshot,
        records: [StoredHealthRecord],
        todayMedicationConfirmed: Bool
    ) -> CaregiverUpdateSnapshot {
        guard profile != nil || !records.isEmpty || pattern.medicationStreak > 0 else {
            return .empty
        }

        let latestBloodReport = records.first(where: { $0.type == .bloodReport })
        let summary = "Today: meds \(todayMedicationConfirmed ? "confirmed" : "not confirmed yet"), pattern \(pattern.riskTier.rawValue), streak \(pattern.medicationStreak) day(s)."

        var lines: [String] = []
        lines.append("LOOK caregiver update")
        lines.append("Person: \(profile?.name.isEmpty == false ? profile?.name ?? "Patient" : "Patient")")
        lines.append("Stage: \(profile?.stage.rawValue ?? "Not set")")
        lines.append(summary)
        if let latestBloodReport {
            lines.append("Latest report: \(latestBloodReport.sourceDateLabel)")
            if !latestBloodReport.flaggedValues.isEmpty {
                lines.append("Flagged labs: \(latestBloodReport.flaggedValues.joined(separator: ", "))")
            }
        }
        lines.append("Suggested action: \(pattern.recommendedAction)")

        return CaregiverUpdateSnapshot(
            preview: summary,
            copyText: lines.joined(separator: "\n")
        )
    }

    static func roadmap(for stage: PatientStage, risk: PatternRiskTier) -> StageRoadmapSnapshot {
        switch stage {
        case .ckd:
            return StageRoadmapSnapshot(
                title: "CKD roadmap",
                subtitle: "Build your baseline early so future care decisions are clearer.",
                actions: [
                    "Track symptoms, labs, and questions before clinic visits.",
                    "Keep a record of costs, hospital options, and language needs.",
                    "Use LOOK to create habits before care becomes more complex."
                ]
            )
        case .dialysis:
            return StageRoadmapSnapshot(
                title: "Dialysis roadmap",
                subtitle: "Reduce chaos around sessions, medication, and access.",
                actions: [
                    "Log fatigue, symptoms, and questions after sessions.",
                    "Use reminders to keep medication timing consistent.",
                    "Prepare one weekly summary for your nephrologist."
                ]
            )
        case .awaitingTransplant:
            return StageRoadmapSnapshot(
                title: "Awaiting transplant roadmap",
                subtitle: "Stay ready with organised records and fewer unknowns.",
                actions: [
                    "Keep your medication and symptom record current.",
                    "Upload recent reports so your baseline is easy to review.",
                    "Use visit packs to keep questions concise and actionable."
                ]
            )
        case .postTransplant:
            return StageRoadmapSnapshot(
                title: risk == .red ? "Post-transplant roadmap: act now" : "Post-transplant roadmap",
                subtitle: "Consistency matters most when daily routines still feel unstable.",
                actions: [
                    "Protect tacrolimus timing and confirm every dose.",
                    "Watch your own baseline on creatinine, eGFR, tacrolimus, and potassium.",
                    risk == .red ? "Escalate concerning trends to your coordinator today." : "Use LOOK to prepare before each doctor visit."
                ]
            )
        case .caregiver:
            return StageRoadmapSnapshot(
                title: "Caregiver roadmap",
                subtitle: "Your job is clarity, continuity, and calm escalation.",
                actions: [
                    "Keep one up-to-date summary ready for emergencies.",
                    "Track missed meds, concerning symptoms, and flagged labs.",
                    "Use caregiver updates to stay aligned without chasing details."
                ]
            )
        }
    }

    static func buildInsights(
        profile: UserProfile?,
        pattern: PatternSnapshot,
        records: [StoredHealthRecord],
        questions: [QuestionEntry],
        trials: [DailyTrial]
    ) -> CareInsightSnapshot {
        let creatinineTrend = extractTrend(metric: focusMetrics[0], from: records)
        let tacrolimusTrend = extractTrend(metric: focusMetrics[2], from: records)
        let latestBloodReport = records.first(where: { $0.type == .bloodReport })
        let recentQuestion = questions.first?.question ?? "No recent question saved."
        let recentNote = trials.first?.friction ?? "No recent trial note."

        let patientHeadline: String
        let patientBody: String

        if let creatinineTrend, creatinineTrend.series.count >= 2, creatinineTrend.status != "normal" {
            patientHeadline = "Your kidney markers need a calmer, closer look."
            patientBody = "Creatinine is drifting away from your recent baseline. Do not panic, but bring this trend, your tacrolimus timing, and any symptom change to your transplant team."
        } else if pattern.riskTier == .red {
            patientHeadline = "Your recent pattern deserves same-day attention."
            patientBody = "LOOK is seeing a higher-risk mix of missed routine steps or support flags. Contact your transplant coordinator and carry your visit pack with you."
        } else if pattern.riskTier == .amber {
            patientHeadline = "You are still stable, but your routine is wobbling."
            patientBody = "A few days of uncertainty or missed adherence are visible. Tighten medication timing and prepare one concise question for your doctor."
        } else {
            patientHeadline = "Your trend looks mostly steady."
            patientBody = "Medication consistency and daily logs are giving you a usable baseline. Keep protecting routine, and keep logging small changes before they become stressful."
        }

        let doctorHeadline = "Clinician brief"
        let doctorBody: String
        var doctorParts: [String] = []
        if let creatinineTrend {
            doctorParts.append("Creatinine \(creatinineTrend.trendLine)")
        }
        if let tacrolimusTrend {
            doctorParts.append("Tacrolimus \(tacrolimusTrend.trendLine)")
        }
        if let latestBloodReport, !latestBloodReport.flaggedValues.isEmpty {
            doctorParts.append("Flagged labs: \(latestBloodReport.flaggedValues.joined(separator: ", "))")
        }
        doctorParts.append("Pattern: \(pattern.summary)")
        doctorParts.append("Recent question: \(recentQuestion)")
        if !recentNote.isEmpty, recentNote != "No doctor note" {
            doctorParts.append("Recent note: \(recentNote)")
        }

        doctorBody = doctorParts.joined(separator: ". ") + "."

        return CareInsightSnapshot(
            patientHeadline: patientHeadline,
            patientBody: patientBody,
            doctorHeadline: doctorHeadline,
            doctorBody: doctorBody
        )
    }

    static func buildWeeklyTrendSnapshot(
        healthLogs: [DailyHealthLog],
        trials: [DailyTrial],
        now: Date = .now
    ) -> WeeklyTrendSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -(6 - offset), to: today)
        }

        let labels = days.map { date in
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        }

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let medicationValues = days.map { date -> Double in
            let key = dayFormatter.string(from: date)
            let log = healthLogs.first(where: { $0.dayKey == key })
            return log?.medicationConfirmedAt != nil ? 1.0 : 0.0
        }

        let checkinScores = days.map { date -> Double in
            let key = dayFormatter.string(from: date)
            guard let status = healthLogs.first(where: { $0.dayKey == key })?.checkinStatus else {
                return 0.0
            }
            switch status {
            case .allGood:
                return 3.0
            case .unsure:
                return 2.0
            case .help:
                return 1.0
            }
        }

        let trialScores = days.map { date -> Double in
            guard let trial = trials.first(where: { calendar.isDate($0.createdAt, inSameDayAs: date) }) else {
                return 0.0
            }
            return Double(trial.rating)
        }

        return WeeklyTrendSnapshot(
            labels: labels,
            medicationValues: medicationValues,
            trialScores: trialScores,
            checkinScores: checkinScores
        )
    }

    private static func saveRecords(_ records: [StoredHealthRecord], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    private static func migrateLegacyRecords(defaults: UserDefaults) -> [StoredHealthRecord] {
        guard let legacy = defaults.array(forKey: legacyRecordsKey) as? [[String: Any]] else {
            return []
        }

        return legacy.compactMap { item in
            guard let typeString = item["type"] as? String else { return nil }
            let type: StoredHealthRecordType = typeString.lowercased().contains("prescription") ? .prescription : .bloodReport
            let dateString = item["date"] as? String ?? "Unknown"
            let summary = item["summary"] as? String ?? ""
            let values = (item["values"] as? [[String: Any]] ?? []).map { value in
                StoredHealthValue(
                    name: value["name"] as? String ?? "",
                    value: value["value"] as? String ?? "",
                    unit: value["unit"] as? String ?? "",
                    status: value["status"] as? String ?? "normal",
                    lookNote: value["lookNote"] as? String ?? ""
                )
            }

            return StoredHealthRecord(
                type: type,
                capturedAt: ISO8601DateFormatter().date(from: dateString) ?? .now,
                sourceDateLabel: dateString,
                summary: summary,
                flaggedValues: item["flaggedValues"] as? [String] ?? [],
                values: values
            )
        }
    }

    private static func extractTrend(metric: FocusMetric, from records: [StoredHealthRecord]) -> HealthMetricTrend? {
        let matches: [(record: StoredHealthRecord, value: StoredHealthValue, numeric: Double)] = records
            .reversed()
            .flatMap { record in
                record.values.compactMap { value -> (StoredHealthRecord, StoredHealthValue, Double)? in
                    guard metric.matches(name: value.name), let numeric = numericValue(from: value.value) else {
                        return nil
                    }
                    return (record, value, numeric)
                }
            }

        guard let latest = matches.last else { return nil }

        let series = matches.map { String(format: "%.2f", $0.numeric) }.joined(separator: " → ")
        let recentValues = matches.suffix(3).map(\.numeric)
        let baseline = recentValues.reduce(0, +) / Double(recentValues.count)

        return HealthMetricTrend(
            metric: metric.displayName,
            latestDisplay: "\(latest.value.value) \(latest.value.unit)".trimmingCharacters(in: .whitespaces),
            baselineText: "Baseline ~\(String(format: "%.2f", baseline))",
            trendLine: matches.count > 1 ? series : "1 report saved",
            status: latest.value.status,
            series: matches.map(\.numeric)
        )
    }

    private static func numericValue(from text: String) -> Double? {
        let pattern = #"-?\d+(\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return Double(text[range])
    }

    private static let focusMetrics: [FocusMetric] = [
        FocusMetric(displayName: "Creatinine", aliases: ["creatinine"]),
        FocusMetric(displayName: "eGFR", aliases: ["egfr"]),
        FocusMetric(displayName: "Tacrolimus", aliases: ["tacrolimus"]),
        FocusMetric(displayName: "Potassium", aliases: ["potassium", "k+"]),
        FocusMetric(displayName: "Haemoglobin", aliases: ["haemoglobin", "hemoglobin"]),
        FocusMetric(displayName: "HbA1c", aliases: ["hba1c"])
    ]
}

private struct FocusMetric {
    let displayName: String
    let aliases: [String]

    func matches(name: String) -> Bool {
        let normalized = name
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return aliases.contains(where: { normalized.contains($0) })
    }
}

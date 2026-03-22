import Foundation
import SwiftData

@MainActor
enum DemoPersonaSeeder {
    private static let seedVersionKey = "look.demoPersonaSeed.v1"
    private static let caregiverNameKey = "profile.caregiverName"
    private static let caregiverRelationKey = "profile.caregiverRelation"
    private static let caregiverContactKey = "profile.caregiverContact"
    private static let medicationsKey = "triallab.medications"
    private static let notificationLogKey = "triallab.notificationLog"
    private static let pendingAcknowledgedKey = "triallab.pendingAcknowledged"

    static func seedIfNeeded(
        modelContext: ModelContext,
        profiles: [UserProfile],
        questions: [QuestionEntry],
        trials: [DailyTrial],
        healthLogs: [DailyHealthLog],
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: seedVersionKey) else { return }
        guard questions.isEmpty, trials.isEmpty, healthLogs.isEmpty, HealthRecordStore.loadRecords(defaults: defaults).isEmpty else {
            return
        }

        let profile = profiles.first ?? UserProfile()
        if profiles.isEmpty {
            modelContext.insert(profile)
        }

        profile.name = "Aarav Shah"
        profile.stage = .postTransplant
        profile.city = .bengaluru
        profile.language = .english
        profile.updatedAt = .now

        seedQuestions(into: modelContext)
        seedHealthLogs(into: modelContext)
        seedTrials(into: modelContext)
        seedHealthRecords(defaults: defaults)
        seedCaregiver(defaults: defaults)
        seedMedicationHub(defaults: defaults)

        try? modelContext.save()
        defaults.set(true, forKey: seedVersionKey)
    }

    private static func seedQuestions(into modelContext: ModelContext) {
        let calendar = Calendar.current
        let base = Date()
        let prompts: [(Int, String)] = [
            (-5, "My creatinine moved from 1.4 to 1.58. Is that something I should ask my transplant doctor this week?"),
            (-4, "I missed my tacrolimus dose by 90 minutes yesterday. What details should I tell my coordinator?"),
            (-2, "Does morning fatigue after transplant usually settle, or should I ask about my haemoglobin?"),
            (-1, "Should I bring my last three blood reports and medication timings to my next appointment?")
        ]

        let triageEngine = TriageEngine()
        for item in prompts {
            let createdAt = calendar.date(byAdding: .day, value: item.0, to: base) ?? base
            let result = triageEngine.evaluate(question: item.1)
            let entry = QuestionEntry(
                question: item.1,
                category: result.category,
                aiSummary: result.summary,
                recommendation: result.recommendation,
                safetyNote: result.safetyNote,
                escalateToHuman: result.escalateToHuman
            )
            entry.createdAt = createdAt
            entry.updatedAt = createdAt
            modelContext.insert(entry)
        }
    }

    private static func seedHealthLogs(into modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let statuses: [CheckinStatus?] = [.allGood, .allGood, .unsure, .allGood, .allGood, .unsure, .allGood]
        let medConfirmed: [Bool] = [true, true, true, false, true, true, true]

        for index in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -(6 - index), to: today) else { continue }
            let dayKey = dayKey(for: day)
            let medTime = medConfirmed[index] ? calendar.date(bySettingHour: 8, minute: 5 + index, second: 0, of: day) : nil
            let checkinTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
            let log = DailyHealthLog(
                dayKey: dayKey,
                createdAt: day,
                updatedAt: day,
                medicationConfirmedAt: medTime,
                checkinCompletedAt: checkinTime,
                checkinStatus: statuses[index]
            )
            modelContext.insert(log)
        }
    }

    private static func seedTrials(into modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let payloads: [(Int, SeedTrialPayload)] = [
            (-6, SeedTrialPayload(triageLevel: "green", q1: 3, q2: 1, q3: 1, q4: 3, doctorNote: "Energy improving after breakfast meds.", medicationConfirmed: true)),
            (-5, SeedTrialPayload(triageLevel: "green", q1: 4, q2: 1, q3: 1, q4: 4, doctorNote: "No swelling, urine output normal.", medicationConfirmed: true)),
            (-4, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 1, q4: 2, doctorNote: "Felt lightheaded late evening; note for doctor.", medicationConfirmed: true)),
            (-3, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 2, q4: 2, doctorNote: "Creatinine anxiety is making sleep worse.", medicationConfirmed: false)),
            (-2, SeedTrialPayload(triageLevel: "green", q1: 3, q2: 1, q3: 1, q4: 3, doctorNote: "Hydration better; want to ask about tacrolimus target.", medicationConfirmed: true)),
            (-1, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 1, q4: 2, doctorNote: "Morning fatigue and mild tremor after tacrolimus.", medicationConfirmed: true))
        ]

        for entry in payloads {
            guard let day = calendar.date(byAdding: .day, value: entry.0, to: today) else { continue }
            let createdAt = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            var payload = entry.1
            payload.logDate = day
            let trial = DailyTrial(
                createdAt: createdAt,
                updatedAt: createdAt,
                rating: derivedRating(for: payload),
                whatWorked: summaryText(for: payload),
                friction: payload.doctorNote,
                nextImprovement: encodePayload(payload)
            )
            modelContext.insert(trial)
        }
    }

    private static func seedHealthRecords(defaults: UserDefaults) {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())

        let records: [StoredHealthRecord] = [
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -21, to: base) ?? base,
                sourceDateLabel: "01 Mar 2026",
                summary: "Creatinine remained close to baseline and tacrolimus sat in the expected range.",
                flaggedValues: [],
                values: [
                    StoredHealthValue(name: "Creatinine", value: "1.32", unit: "mg/dL", status: "normal", lookNote: "Close to your current baseline."),
                    StoredHealthValue(name: "eGFR", value: "64", unit: "mL/min", status: "normal", lookNote: "Stable filtration for this stage."),
                    StoredHealthValue(name: "Tacrolimus trough", value: "7.8", unit: "ng/mL", status: "normal", lookNote: "Within the usual target window."),
                    StoredHealthValue(name: "Potassium", value: "4.6", unit: "mmol/L", status: "normal", lookNote: "No electrolyte concern visible."),
                    StoredHealthValue(name: "Haemoglobin", value: "11.4", unit: "g/dL", status: "low", lookNote: "This can contribute to fatigue after transplant.")
                ]
            ),
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -10, to: base) ?? base,
                sourceDateLabel: "12 Mar 2026",
                summary: "Creatinine edged up slightly and haemoglobin stayed a little low.",
                flaggedValues: ["Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Creatinine", value: "1.45", unit: "mg/dL", status: "high", lookNote: "Slightly above your earlier report, worth watching against symptoms and hydration."),
                    StoredHealthValue(name: "eGFR", value: "59", unit: "mL/min", status: "normal", lookNote: "A small shift can happen when creatinine moves."),
                    StoredHealthValue(name: "Tacrolimus trough", value: "8.1", unit: "ng/mL", status: "normal", lookNote: "Still broadly near range."),
                    StoredHealthValue(name: "Potassium", value: "4.8", unit: "mmol/L", status: "normal", lookNote: "Still acceptable."),
                    StoredHealthValue(name: "Haemoglobin", value: "10.9", unit: "g/dL", status: "low", lookNote: "Low haemoglobin may be part of your fatigue story.")
                ]
            ),
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -2, to: base) ?? base,
                sourceDateLabel: "20 Mar 2026",
                summary: "Creatinine and tacrolimus are both above your earlier reports, so timing and doctor review matter.",
                flaggedValues: ["Creatinine", "Tacrolimus trough", "Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Creatinine", value: "1.58", unit: "mg/dL", status: "high", lookNote: "This is above your recent baseline, so take the full trend to your transplant team."),
                    StoredHealthValue(name: "eGFR", value: "54", unit: "mL/min", status: "low", lookNote: "A lower eGFR can reflect the same shift seen in creatinine."),
                    StoredHealthValue(name: "Tacrolimus trough", value: "9.4", unit: "ng/mL", status: "high", lookNote: "Higher tacrolimus levels can matter if dosing or timing changed."),
                    StoredHealthValue(name: "Potassium", value: "5.1", unit: "mmol/L", status: "high", lookNote: "Slight potassium rise should be reviewed with diet and medication timing."),
                    StoredHealthValue(name: "Haemoglobin", value: "10.7", unit: "g/dL", status: "low", lookNote: "This still may contribute to fatigue and low stamina.")
                ]
            ),
            StoredHealthRecord(
                type: .prescription,
                capturedAt: calendar.date(byAdding: .day, value: -1, to: base) ?? base,
                sourceDateLabel: "21 Mar 2026",
                summary: "Tacrolimus, mycophenolate, prednisolone, and pantoprazole remain active on the latest prescription.",
                flaggedValues: [],
                values: [
                    StoredHealthValue(name: "Tacrolimus", value: "1 mg", unit: "twice daily", status: "normal", lookNote: "Timing matters more than it feels."),
                    StoredHealthValue(name: "Mycophenolate", value: "500 mg", unit: "twice daily", status: "normal", lookNote: "Keep this aligned with your prescription."),
                    StoredHealthValue(name: "Prednisolone", value: "5 mg", unit: "morning", status: "normal", lookNote: "Steroid taper and timing should stay clinician-led.")
                ]
            )
        ]

        HealthRecordStore.replaceAll(records, defaults: defaults)
    }

    private static func seedCaregiver(defaults: UserDefaults) {
        defaults.set("Nisha Shah", forKey: caregiverNameKey)
        defaults.set("Mother", forKey: caregiverRelationKey)
        defaults.set("+91 98765 43210", forKey: caregiverContactKey)
    }

    private static func seedMedicationHub(defaults: UserDefaults) {
        let meds = [
            SeedMedicationRecord(name: "Tacrolimus", dose: "1mg × 2 daily", times: ["8:00 AM", "8:00 PM"], reminderActive: true),
            SeedMedicationRecord(name: "Mycophenolate", dose: "500mg × 2 daily", times: ["9:00 AM", "9:00 PM"], reminderActive: true),
            SeedMedicationRecord(name: "Prednisolone", dose: "5mg morning", times: ["8:00 AM"], reminderActive: true)
        ]
        let log = [
            SeedNotificationEntry(icon: "💊", title: "Tacrolimus 8:00 AM - Acknowledged", time: "8:04 AM", status: "acknowledged"),
            SeedNotificationEntry(icon: "💊", title: "Mycophenolate 9:00 AM - Acknowledged", time: "9:02 AM", status: "acknowledged"),
            SeedNotificationEntry(icon: "🔔", title: "Tacrolimus 8:00 PM - Pending", time: "Due at 8:00 PM", status: "pending")
        ]

        if let medsData = try? JSONEncoder().encode(meds) {
            defaults.set(medsData, forKey: medicationsKey)
        }
        if let logData = try? JSONEncoder().encode(log) {
            defaults.set(logData, forKey: notificationLogKey)
        }
        defaults.set(false, forKey: pendingAcknowledgedKey)
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func summaryText(for payload: SeedTrialPayload) -> String {
        "Triage \(payload.triageLevel) · energy \(payload.q1) · symptoms \(payload.q2) · meds \(payload.q3) · emotion \(payload.q4)"
    }

    private static func encodePayload(_ payload: SeedTrialPayload) -> String {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return payload.doctorNote
        }
        return "LOOK_TRIAL_V2|\(json)"
    }

    private static func derivedRating(for payload: SeedTrialPayload) -> Int {
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
        case "red", "none":
            break
        default:
            break
        }

        return min(max(Int(round(Double(score) / 4.2)), 1), 5)
    }
}

private struct SeedTrialPayload: Codable {
    var triageLevel: String
    var q1: Int
    var q2: Int
    var q3: Int
    var q4: Int
    var doctorNote: String
    var medicationConfirmed: Bool
    var logDate: Date = .now
}

private struct SeedMedicationRecord: Codable {
    var id: UUID = UUID()
    var name: String
    var dose: String
    var times: [String]
    var reminderActive: Bool
}

private struct SeedNotificationEntry: Codable {
    var id: UUID = UUID()
    var icon: String
    var title: String
    var time: String
    var status: String
}

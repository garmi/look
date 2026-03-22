import Foundation
import SwiftData

@MainActor
enum DemoPersonaSeeder {
    private static let seedVersionKey = "look.demoPersonaSeed.v2"
    private static let selectedPresetKey = "look.demoPersonaSelectedPreset"
    private static let caregiverNameKey = "profile.caregiverName"
    private static let caregiverRelationKey = "profile.caregiverRelation"
    private static let caregiverContactKey = "profile.caregiverContact"
    private static let medicationsKey = "triallab.medications"
    private static let notificationLogKey = "triallab.notificationLog"
    private static let pendingAcknowledgedKey = "triallab.pendingAcknowledged"

    static func requiresSelection(
        questions: [QuestionEntry],
        trials: [DailyTrial],
        healthLogs: [DailyHealthLog],
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: seedVersionKey) else { return false }
        return questions.isEmpty && trials.isEmpty && healthLogs.isEmpty && HealthRecordStore.loadRecords(defaults: defaults).isEmpty
    }

    static func selectedPreset(defaults: UserDefaults = .standard) -> DemoPersonaPreset? {
        guard let rawValue = defaults.string(forKey: selectedPresetKey) else { return nil }
        return DemoPersonaPreset(rawValue: rawValue)
    }

    static func seed(
        preset: DemoPersonaPreset,
        modelContext: ModelContext,
        profiles: [UserProfile],
        defaults: UserDefaults = .standard
    ) {
        let blueprint = blueprint(for: preset)
        let profile = profiles.first ?? UserProfile()
        if profiles.isEmpty {
            modelContext.insert(profile)
        }

        profile.name = blueprint.name
        profile.stage = blueprint.stage
        profile.city = blueprint.city
        profile.language = blueprint.language
        profile.updatedAt = .now

        seedQuestions(into: modelContext, prompts: blueprint.questions)
        seedHealthLogs(into: modelContext, statuses: blueprint.checkinStatuses, medicationFlags: blueprint.medicationFlags)
        seedTrials(into: modelContext, payloads: blueprint.trials)
        HealthRecordStore.replaceAll(blueprint.records, defaults: defaults)
        seedCaregiver(defaults: defaults, caregiver: blueprint.caregiver)
        seedMedicationHub(defaults: defaults, medications: blueprint.medications, log: blueprint.notificationLog, pendingAcknowledged: blueprint.pendingAcknowledged)

        try? modelContext.save()
        defaults.set(true, forKey: seedVersionKey)
        defaults.set(preset.rawValue, forKey: selectedPresetKey)
    }

    static func seedIfNeeded(
        modelContext: ModelContext,
        profiles: [UserProfile],
        questions: [QuestionEntry],
        trials: [DailyTrial],
        healthLogs: [DailyHealthLog],
        defaults: UserDefaults = .standard
    ) {
        guard requiresSelection(questions: questions, trials: trials, healthLogs: healthLogs, defaults: defaults) else { return }
        seed(preset: .aarav, modelContext: modelContext, profiles: profiles, defaults: defaults)
    }

    private static func seedQuestions(into modelContext: ModelContext, prompts: [(Int, String)]) {
        let calendar = Calendar.current
        let base = Date()
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

    private static func seedHealthLogs(
        into modelContext: ModelContext,
        statuses: [CheckinStatus?],
        medicationFlags: [Bool]
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for index in 0..<min(statuses.count, medicationFlags.count) {
            guard let day = calendar.date(byAdding: .day, value: -(statuses.count - 1 - index), to: today) else { continue }
            let dayKey = dayKey(for: day)
            let medTime = medicationFlags[index] ? calendar.date(bySettingHour: 8, minute: 5 + index, second: 0, of: day) : nil
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

    private static func seedTrials(into modelContext: ModelContext, payloads: [(Int, SeedTrialPayload)]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

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

    private static func seedCaregiver(defaults: UserDefaults, caregiver: SeedCaregiver) {
        defaults.set(caregiver.name, forKey: caregiverNameKey)
        defaults.set(caregiver.relation, forKey: caregiverRelationKey)
        defaults.set(caregiver.contact, forKey: caregiverContactKey)
    }

    private static func seedMedicationHub(
        defaults: UserDefaults,
        medications: [SeedMedicationRecord],
        log: [SeedNotificationEntry],
        pendingAcknowledged: Bool
    ) {
        if let medsData = try? JSONEncoder().encode(medications) {
            defaults.set(medsData, forKey: medicationsKey)
        }
        if let logData = try? JSONEncoder().encode(log) {
            defaults.set(logData, forKey: notificationLogKey)
        }
        defaults.set(pendingAcknowledged, forKey: pendingAcknowledgedKey)
    }

    private static func blueprint(for preset: DemoPersonaPreset) -> SeedBlueprint {
        switch preset {
        case .aarav:
            return SeedBlueprint(
                name: "Aarav Shah",
                stage: .postTransplant,
                city: .bengaluru,
                language: .english,
                caregiver: SeedCaregiver(name: "Nisha Shah", relation: "Mother", contact: "+91 98765 43210"),
                questions: [
                    (-5, "My creatinine moved from 1.4 to 1.58. Is that something I should ask my transplant doctor this week?"),
                    (-4, "I missed my tacrolimus dose by 90 minutes yesterday. What details should I tell my coordinator?"),
                    (-2, "Does morning fatigue after transplant usually settle, or should I ask about my haemoglobin?"),
                    (-1, "Should I bring my last three blood reports and medication timings to my next appointment?")
                ],
                checkinStatuses: [.allGood, .allGood, .unsure, .allGood, .allGood, .unsure, .allGood],
                medicationFlags: [true, true, true, false, true, true, true],
                trials: [
                    (-6, SeedTrialPayload(triageLevel: "green", q1: 3, q2: 1, q3: 1, q4: 3, doctorNote: "Energy improving after breakfast meds.", medicationConfirmed: true)),
                    (-5, SeedTrialPayload(triageLevel: "green", q1: 4, q2: 1, q3: 1, q4: 4, doctorNote: "No swelling, urine output normal.", medicationConfirmed: true)),
                    (-4, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 1, q4: 2, doctorNote: "Felt lightheaded late evening; note for doctor.", medicationConfirmed: true)),
                    (-3, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 2, q4: 2, doctorNote: "Creatinine anxiety is making sleep worse.", medicationConfirmed: false)),
                    (-2, SeedTrialPayload(triageLevel: "green", q1: 3, q2: 1, q3: 1, q4: 3, doctorNote: "Hydration better; want to ask about tacrolimus target.", medicationConfirmed: true)),
                    (-1, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 1, q4: 2, doctorNote: "Morning fatigue and mild tremor after tacrolimus.", medicationConfirmed: true))
                ],
                records: aaravRecords(),
                medications: [
                    SeedMedicationRecord(name: "Tacrolimus", dose: "1mg × 2 daily", times: ["8:00 AM", "8:00 PM"], reminderActive: true),
                    SeedMedicationRecord(name: "Mycophenolate", dose: "500mg × 2 daily", times: ["9:00 AM", "9:00 PM"], reminderActive: true),
                    SeedMedicationRecord(name: "Prednisolone", dose: "5mg morning", times: ["8:00 AM"], reminderActive: true)
                ],
                notificationLog: [
                    SeedNotificationEntry(icon: "💊", title: "Tacrolimus 8:00 AM - Acknowledged", time: "8:04 AM", status: "acknowledged"),
                    SeedNotificationEntry(icon: "💊", title: "Mycophenolate 9:00 AM - Acknowledged", time: "9:02 AM", status: "acknowledged"),
                    SeedNotificationEntry(icon: "🔔", title: "Tacrolimus 8:00 PM - Pending", time: "Due at 8:00 PM", status: "pending")
                ],
                pendingAcknowledged: false
            )
        case .meera:
            return SeedBlueprint(
                name: "Meera Reddy",
                stage: .dialysis,
                city: .hyderabad,
                language: .telugu,
                caregiver: SeedCaregiver(name: "Rajesh Reddy", relation: "Husband", contact: "+91 91234 56789"),
                questions: [
                    (-6, "Can I reduce post-dialysis fatigue before work days?"),
                    (-4, "What should I track between dialysis sessions for a more useful doctor conversation?"),
                    (-2, "Should I log cramps and dizziness separately or together in the app?")
                ],
                checkinStatuses: [.allGood, .allGood, .allGood, .unsure, .allGood, .allGood, .allGood],
                medicationFlags: [true, true, true, true, true, true, true],
                trials: [
                    (-6, SeedTrialPayload(triageLevel: "green", q1: 3, q2: 1, q3: 1, q4: 3, doctorNote: "Dialysis fatigue settled by evening.", medicationConfirmed: true)),
                    (-5, SeedTrialPayload(triageLevel: "green", q1: 4, q2: 1, q3: 1, q4: 4, doctorNote: "No new symptoms between sessions.", medicationConfirmed: true)),
                    (-4, SeedTrialPayload(triageLevel: "green", q1: 3, q2: 1, q3: 1, q4: 3, doctorNote: "Mild cramps only after longer walk.", medicationConfirmed: true)),
                    (-3, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 1, q4: 2, doctorNote: "One heavier fatigue day after dialysis.", medicationConfirmed: true)),
                    (-2, SeedTrialPayload(triageLevel: "green", q1: 3, q2: 1, q3: 1, q4: 4, doctorNote: "Better appetite and fewer cramps.", medicationConfirmed: true)),
                    (-1, SeedTrialPayload(triageLevel: "green", q1: 4, q2: 1, q3: 1, q4: 4, doctorNote: "Strong week overall, questions ready for nephrologist.", medicationConfirmed: true))
                ],
                records: meeraRecords(),
                medications: [
                    SeedMedicationRecord(name: "Sevelamer", dose: "800mg with meals", times: ["8:00 AM", "1:00 PM", "8:00 PM"], reminderActive: true),
                    SeedMedicationRecord(name: "Erythropoietin", dose: "As prescribed", times: ["Dialysis days"], reminderActive: true)
                ],
                notificationLog: [
                    SeedNotificationEntry(icon: "💊", title: "Sevelamer breakfast dose - Acknowledged", time: "8:10 AM", status: "acknowledged"),
                    SeedNotificationEntry(icon: "💊", title: "Sevelamer lunch dose - Acknowledged", time: "1:05 PM", status: "acknowledged"),
                    SeedNotificationEntry(icon: "💊", title: "Sevelamer dinner dose - Pending", time: "Due at 8:00 PM", status: "pending")
                ],
                pendingAcknowledged: false
            )
        case .imran:
            return SeedBlueprint(
                name: "Imran Khan",
                stage: .awaitingTransplant,
                city: .bengaluru,
                language: .hindi,
                caregiver: SeedCaregiver(name: "Farah Khan", relation: "Sister", contact: "+91 99876 54321"),
                questions: [
                    (-6, "Which hospital desk should I call for financial support?"),
                    (-5, "What should I organize before a transplant call can come?"),
                    (-3, "If I miss a medication once while traveling, what details matter most?"),
                    (-1, "Can I prepare one summary for both donor screening and nephrology follow-up?")
                ],
                checkinStatuses: [.unsure, .unsure, .help, .unsure, .help, .unsure, .unsure],
                medicationFlags: [true, false, true, false, false, true, false],
                trials: [
                    (-6, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 1, q4: 2, doctorNote: "Travel and cost stress are making routines hard.", medicationConfirmed: true)),
                    (-5, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 2, q4: 2, doctorNote: "Missed one medication while outside the city.", medicationConfirmed: false)),
                    (-4, SeedTrialPayload(triageLevel: "red", q1: 1, q2: 3, q3: 3, q4: 1, doctorNote: "Sleep is poor and anxiety is high before appointments.", medicationConfirmed: false)),
                    (-3, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 2, q4: 2, doctorNote: "Trying to coordinate reports and funding paperwork.", medicationConfirmed: true)),
                    (-2, SeedTrialPayload(triageLevel: "red", q1: 1, q2: 3, q3: 3, q4: 1, doctorNote: "Felt overwhelmed and did not complete the day properly.", medicationConfirmed: false)),
                    (-1, SeedTrialPayload(triageLevel: "amber", q1: 2, q2: 2, q3: 1, q4: 2, doctorNote: "Need caregiver help to keep questions and meds organised.", medicationConfirmed: true))
                ],
                records: imranRecords(),
                medications: [
                    SeedMedicationRecord(name: "Antihypertensive", dose: "As prescribed", times: ["9:00 AM"], reminderActive: true),
                    SeedMedicationRecord(name: "Phosphate binder", dose: "With meals", times: ["1:00 PM", "8:00 PM"], reminderActive: true)
                ],
                notificationLog: [
                    SeedNotificationEntry(icon: "⚠️", title: "Morning medication - Missed", time: "9:45 AM", status: "missed"),
                    SeedNotificationEntry(icon: "💊", title: "Dinner dose - Pending", time: "Due at 8:00 PM", status: "pending"),
                    SeedNotificationEntry(icon: "💊", title: "Yesterday dinner dose - Acknowledged", time: "8:18 PM", status: "acknowledged")
                ],
                pendingAcknowledged: false
            )
        }
    }

    private static func aaravRecords() -> [StoredHealthRecord] {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        return [
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
    }

    private static func meeraRecords() -> [StoredHealthRecord] {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        return [
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -20, to: base) ?? base,
                sourceDateLabel: "02 Mar 2026",
                summary: "Potassium and urea remained broadly stable across this dialysis cycle.",
                flaggedValues: ["Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Potassium", value: "4.7", unit: "mmol/L", status: "normal", lookNote: "Reasonably stable for dialysis care."),
                    StoredHealthValue(name: "Haemoglobin", value: "10.2", unit: "g/dL", status: "low", lookNote: "Low haemoglobin may explain fatigue after sessions."),
                    StoredHealthValue(name: "Urea", value: "64", unit: "mg/dL", status: "normal", lookNote: "Use the trend, not one isolated value.")
                ]
            ),
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -9, to: base) ?? base,
                sourceDateLabel: "13 Mar 2026",
                summary: "No major movement in potassium; haemoglobin improved slightly.",
                flaggedValues: ["Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Potassium", value: "4.8", unit: "mmol/L", status: "normal", lookNote: "Still in a similar zone to the previous report."),
                    StoredHealthValue(name: "Haemoglobin", value: "10.4", unit: "g/dL", status: "low", lookNote: "Slight improvement, though fatigue may still be present."),
                    StoredHealthValue(name: "Urea", value: "62", unit: "mg/dL", status: "normal", lookNote: "No meaningful change here.")
                ]
            ),
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -1, to: base) ?? base,
                sourceDateLabel: "21 Mar 2026",
                summary: "Overall pattern is stable, which supports calmer weekly reviews.",
                flaggedValues: ["Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Potassium", value: "4.6", unit: "mmol/L", status: "normal", lookNote: "A reassuringly stable trend."),
                    StoredHealthValue(name: "Haemoglobin", value: "10.5", unit: "g/dL", status: "low", lookNote: "Still low, but moving in the right direction."),
                    StoredHealthValue(name: "Urea", value: "63", unit: "mg/dL", status: "normal", lookNote: "Essentially flat compared with earlier reports.")
                ]
            )
        ]
    }

    private static func imranRecords() -> [StoredHealthRecord] {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        return [
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -18, to: base) ?? base,
                sourceDateLabel: "04 Mar 2026",
                summary: "Creatinine and potassium were high enough to keep close track of between visits.",
                flaggedValues: ["Creatinine", "Potassium", "Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Creatinine", value: "5.1", unit: "mg/dL", status: "high", lookNote: "This needs ongoing nephrology review."),
                    StoredHealthValue(name: "Potassium", value: "5.0", unit: "mmol/L", status: "high", lookNote: "Diet and medication guidance matter here."),
                    StoredHealthValue(name: "Haemoglobin", value: "9.8", unit: "g/dL", status: "low", lookNote: "Can strongly contribute to low energy and poor stamina.")
                ]
            ),
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -8, to: base) ?? base,
                sourceDateLabel: "14 Mar 2026",
                summary: "Potassium edged higher and haemoglobin dipped, which can make adherence feel harder.",
                flaggedValues: ["Creatinine", "Potassium", "Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Creatinine", value: "5.4", unit: "mg/dL", status: "high", lookNote: "This reflects continued kidney burden while awaiting transplant."),
                    StoredHealthValue(name: "Potassium", value: "5.3", unit: "mmol/L", status: "high", lookNote: "Worth discussing urgently if there are symptoms or repeated highs."),
                    StoredHealthValue(name: "Haemoglobin", value: "9.5", unit: "g/dL", status: "low", lookNote: "Low haemoglobin may worsen anxiety and fatigue together.")
                ]
            ),
            StoredHealthRecord(
                type: .bloodReport,
                capturedAt: calendar.date(byAdding: .day, value: -2, to: base) ?? base,
                sourceDateLabel: "20 Mar 2026",
                summary: "There is still no comfortable buffer here; routine support and care coordination matter.",
                flaggedValues: ["Creatinine", "Potassium", "Haemoglobin"],
                values: [
                    StoredHealthValue(name: "Creatinine", value: "5.2", unit: "mg/dL", status: "high", lookNote: "Still far above a stable baseline target."),
                    StoredHealthValue(name: "Potassium", value: "5.1", unit: "mmol/L", status: "high", lookNote: "Not a value to manage casually without clinician input."),
                    StoredHealthValue(name: "Haemoglobin", value: "9.7", unit: "g/dL", status: "low", lookNote: "This remains part of the fatigue story.")
                ]
            )
        ]
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

private struct SeedBlueprint {
    var name: String
    var stage: PatientStage
    var city: CityChoice
    var language: LanguageChoice
    var caregiver: SeedCaregiver
    var questions: [(Int, String)]
    var checkinStatuses: [CheckinStatus?]
    var medicationFlags: [Bool]
    var trials: [(Int, SeedTrialPayload)]
    var records: [StoredHealthRecord]
    var medications: [SeedMedicationRecord]
    var notificationLog: [SeedNotificationEntry]
    var pendingAcknowledged: Bool
}

private struct SeedCaregiver {
    var name: String
    var relation: String
    var contact: String
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

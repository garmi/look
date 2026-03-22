import Foundation

enum DemoPersonaPreset: String, CaseIterable, Identifiable {
    case aarav
    case meera
    case imran

    var id: String { rawValue }
}

struct DemoPersonaJourney: Identifiable {
    let preset: DemoPersonaPreset
    let name: String
    let ageLabel: String
    let stage: PatientStage
    let city: CityChoice
    let language: LanguageChoice
    let headline: String
    let patientInsight: String
    let doctorInsight: String
    let labels: [String]
    let medicationTrend: [Double]
    let checkinTrend: [Double]
    let trialTrend: [Double]
    let questionTrend: [Double]
    let labMetrics: [DemoPersonaLabMetric]
    let keyQuestions: [String]

    var id: String { preset.rawValue }
}

struct DemoPersonaLabMetric: Identifiable {
    let id = UUID()
    let metric: String
    let unit: String
    let values: [Double]
    let status: String
}

enum DemoPersonaLibrary {
    static let journeys: [DemoPersonaJourney] = [
        DemoPersonaJourney(
            preset: .aarav,
            name: "Aarav Shah",
            ageLabel: "31 yrs",
            stage: .postTransplant,
            city: .bengaluru,
            language: .english,
            headline: "Early post-transplant patient with mild creatinine drift and mostly strong adherence.",
            patientInsight: "Aarav is mostly consistent, but fatigue plus a few amber days suggest he benefits from tighter medication timing and better visit prep.",
            doctorInsight: "Trend shows rising creatinine and tacrolimus over three reports with intermittent fatigue and tremor notes. Worth reviewing dose timing, hydration, and latest target range.",
            labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            medicationTrend: [1, 1, 1, 0, 1, 1, 1],
            checkinTrend: [3, 3, 2, 2, 3, 2, 3],
            trialTrend: [4.1, 4.3, 3.2, 2.9, 3.8, 3.1, 3.6],
            questionTrend: [0, 1, 0, 1, 0, 1, 1],
            labMetrics: [
                DemoPersonaLabMetric(metric: "Creatinine", unit: "mg/dL", values: [1.32, 1.45, 1.58], status: "high"),
                DemoPersonaLabMetric(metric: "Tacrolimus", unit: "ng/mL", values: [7.8, 8.1, 9.4], status: "high"),
                DemoPersonaLabMetric(metric: "Haemoglobin", unit: "g/dL", values: [11.4, 10.9, 10.7], status: "low")
            ],
            keyQuestions: [
                "Should I bring my last three blood reports and medication timings?",
                "Does morning fatigue after transplant usually settle?"
            ]
        ),
        DemoPersonaJourney(
            preset: .meera,
            name: "Meera Reddy",
            ageLabel: "42 yrs",
            stage: .dialysis,
            city: .hyderabad,
            language: .telugu,
            headline: "Dialysis patient with strong routine, good logging behavior, and stable symptom pattern.",
            patientInsight: "Meera shows how LOOK can become a calm weekly rhythm: steady questions, steady logs, and very few support flags.",
            doctorInsight: "Adherence and symptom burden are stable. Primary value here is continuity: dialysis fatigue notes, recurring questions, and clean appointment prep.",
            labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            medicationTrend: [1, 1, 1, 1, 1, 1, 1],
            checkinTrend: [3, 3, 3, 2, 3, 3, 3],
            trialTrend: [3.8, 4.0, 3.7, 3.5, 3.9, 4.1, 3.8],
            questionTrend: [1, 0, 1, 0, 0, 1, 0],
            labMetrics: [
                DemoPersonaLabMetric(metric: "Potassium", unit: "mmol/L", values: [4.7, 4.8, 4.6], status: "normal"),
                DemoPersonaLabMetric(metric: "Haemoglobin", unit: "g/dL", values: [10.2, 10.4, 10.5], status: "low"),
                DemoPersonaLabMetric(metric: "Urea", unit: "mg/dL", values: [64, 62, 63], status: "normal")
            ],
            keyQuestions: [
                "Can I reduce post-dialysis fatigue before work days?",
                "What should I track between sessions for better discussions?"
            ]
        ),
        DemoPersonaJourney(
            preset: .imran,
            name: "Imran Khan",
            ageLabel: "27 yrs",
            stage: .awaitingTransplant,
            city: .bengaluru,
            language: .hindi,
            headline: "Awaiting-transplant patient with inconsistent routine, rising anxiety, and multiple access questions.",
            patientInsight: "Imran needs workflow support more than content depth right now: reminders, one caregiver loop, and simpler next-step prompts.",
            doctorInsight: "Pattern is more behavioral than clinical. Missed routines, frequent amber/red check-ins, and multiple unresolved access questions suggest care coordination support is needed.",
            labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            medicationTrend: [1, 0, 1, 0, 0, 1, 0],
            checkinTrend: [2, 2, 1, 2, 1, 2, 2],
            trialTrend: [2.8, 2.6, 2.1, 2.9, 2.2, 3.0, 2.7],
            questionTrend: [1, 1, 0, 1, 1, 0, 1],
            labMetrics: [
                DemoPersonaLabMetric(metric: "Creatinine", unit: "mg/dL", values: [5.1, 5.4, 5.2], status: "high"),
                DemoPersonaLabMetric(metric: "Potassium", unit: "mmol/L", values: [5.0, 5.3, 5.1], status: "high"),
                DemoPersonaLabMetric(metric: "Haemoglobin", unit: "g/dL", values: [9.8, 9.5, 9.7], status: "low")
            ],
            keyQuestions: [
                "Which hospital desk should I call for financial support?",
                "What should I organize before a transplant call can come?"
            ]
        )
    ]

    static func journey(for preset: DemoPersonaPreset) -> DemoPersonaJourney {
        journeys.first(where: { $0.preset == preset }) ?? journeys[0]
    }
}

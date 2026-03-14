import SwiftData
import SwiftUI
import UIKit

private let sunriseOrange = Color(red: 0.91, green: 0.53, blue: 0.23)
private let healTeal = Color(red: 0.00, green: 0.48, blue: 0.48)
private let sageGreen = Color(red: 0.29, green: 0.49, blue: 0.35)
private let warmDawn = Color(red: 0.98, green: 0.97, blue: 0.95)
private let darkInk = Color(red: 0.11, green: 0.11, blue: 0.18)
private let mutedSand = Color(red: 0.71, green: 0.66, blue: 0.60)
private let parchment = Color(red: 0.98, green: 0.98, blue: 0.97)

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var questions: [QuestionEntry]
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]
    @Query(sort: \DailyHealthLog.dayKey, order: .reverse) private var healthLogs: [DailyHealthLog]
    @Query private var profiles: [UserProfile]

    @State private var checkinOpen: Bool = false
    @State private var checkinDone: Bool = false
    @State private var checkinResponse: String = ""
    @State private var checkinColor: Color = .clear
    @State private var medTaken: Bool = false
    @State private var showMedHint: Bool = false
    @State private var insightIndex: Int = {
        Calendar.current.component(.weekday, from: Date()) - 1
    }()
    @State private var questionCount: Int = 0
    @State private var trialCount: Int = 0
    @State private var dayStreak: Int = 847
    @State private var patternSnapshot: PatternSnapshot = .empty
    @State private var trialMetrics: DashboardTrialMetrics = .empty
    @State private var medicationHubSnapshot: DashboardMedicationSnapshot = .empty
    @State private var pulseQuestions: Bool = false
    @State private var pulseTrials: Bool = false
    @State private var checkinHintVisible: Bool = false
    @State private var checkinScale: CGFloat = 1.0
    @State private var medicationConfirmedAt: Date?
    @State private var insightHintVisible: Bool = true

    private let insights: [String] = [
        "Month 1–3 post-transplant is when most patients feel worst but are healing fastest. Trust the process.",
        "Missing even one dose of tacrolimus can trigger rejection. The pill works invisibly — take it anyway.",
        "Your creatinine number is not your enemy. It is information. Learn your baseline, not what the internet says.",
        "Fatigue after transplant is real. It is not weakness. Your body is doing extraordinary repair work.",
        "The question you are embarrassed to ask your doctor is usually the most important one. Write it down.",
        "Long-term immunosuppression changes your sun sensitivity. Sunscreen is not optional after a transplant.",
        "One year post-transplant looks nothing like three months. Give yourself the full timeline."
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                headerSection
                sunriseBand
                checkinCard
                medicationCard
                streakBar
                insightCard
                statsRow
                safetyCard
            }
            .padding(.bottom, 24)
        }
        .background(parchment.ignoresSafeArea())
        .onAppear {
            refreshDashboardMetrics()
            loadTodayState()
            pulseQuestions = true
            pulseTrials = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshDashboardMetrics()
        }
        .onChange(of: questions.count) { _, newValue in
            questionCount = newValue
        }
        .onChange(of: trials.count) { _, _ in
            refreshDashboardMetrics()
        }
        .onChange(of: healthLogs.count) { _, _ in
            refreshDashboardMetrics()
            loadTodayState()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate())
                .font(bodyFont(11))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(mutedSand)

            (
                Text("Good ")
                + Text("morning,").italic().foregroundStyle(sunriseOrange)
                + Text("\n\(greetingInitial).")
            )
            .font(displayFont(32))
            .foregroundStyle(darkInk)
            .lineSpacing(2)

            Text("Day \(dayStreak) of your second chance.")
                .font(bodyFont(13))
                .fontWeight(.light)
                .foregroundStyle(mutedSand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private var sunriseBand: some View {
        LinearGradient(
            colors: [
                sunriseOrange,
                Color(red: 0.96, green: 0.76, blue: 0.50),
                Color(red: 0.83, green: 0.77, blue: 0.71)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 3)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .opacity(0.6)
        .padding(.horizontal, 20)
    }

    private var checkinCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(darkInk)

            Circle()
                .fill(sunriseOrange.opacity(0.28))
                .frame(width: 110, height: 110)
                .blur(radius: 36)
                .offset(x: 100, y: -70)

            Circle()
                .fill(healTeal.opacity(0.18))
                .frame(width: 120, height: 120)
                .blur(radius: 42)
                .offset(x: -105, y: 75)

            VStack(alignment: .leading, spacing: 12) {
                Text("MORNING CHECK-IN")
                    .font(bodyFont(10))
                    .tracking(1.5)
                    .foregroundStyle(mutedSand.opacity(0.4))

                Text("How are you\nfeeling today?")
                    .font(displayFont(20))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                if checkinDone {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(checkinResponse)
                            .font(bodyFont(12, weight: .medium))
                            .foregroundStyle(checkinColor)

                        Text("LOOK is not a medical service. Always confirm with your doctor.")
                            .font(bodyFont(10))
                            .italic()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else if checkinOpen {
                    HStack(spacing: 8) {
                        checkinChip(
                            label: "🟢  All good",
                            foreground: sageGreen,
                            background: sageGreen.opacity(0.15)
                        ) {
                            submitCheckin(
                                status: .allGood,
                                response: "Logged. Keep it up. Your consistency matters.",
                                color: Color(red: 0.49, green: 0.78, blue: 0.63)
                            )
                        }

                        checkinChip(
                            label: "🟡  Unsure",
                            foreground: sunriseOrange,
                            background: sunriseOrange.opacity(0.15)
                        ) {
                            submitCheckin(
                                status: .unsure,
                                response: "Noted. Consider calling your transplant coordinator today.",
                                color: Color(red: 0.96, green: 0.76, blue: 0.50)
                            )
                        }

                        checkinChip(
                            label: "🔴  Help",
                            foreground: .red,
                            background: Color.red.opacity(0.12)
                        ) {
                            submitCheckin(
                                status: .help,
                                response: "Please contact your doctor or go to your nearest hospital now.",
                                color: Color(red: 0.96, green: 0.57, blue: 0.57)
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("Double-tap to respond")
                        .font(bodyFont(10))
                        .foregroundStyle(.white.opacity(checkinHintVisible ? 0.65 : 0.3))
                        .animation(.easeInOut(duration: 0.25), value: checkinHintVisible)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .scaleEffect(checkinScale)
        .modifier(LOOKCard(background: .clear, borderColor: .clear))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                checkinOpen = true
                checkinScale = 1.02
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    checkinScale = 1.0
                }
            }
        }
        .onTapGesture {
            guard !checkinOpen else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                checkinHintVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    checkinHintVisible = false
                }
            }
        }
    }

    private var medicationCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(medTaken ? sageGreen.opacity(0.12) : healTeal.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay {
                        if medTaken {
                            Text("✓")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(sageGreen)
                        } else {
                            Text("💊")
                                .font(.system(size: 18))
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Medication")
                        .font(bodyFont(15, weight: .medium))
                        .foregroundStyle(darkInk)

                    Text(medicationSubtitle)
                        .font(bodyFont(12))
                        .fontWeight(.light)
                        .foregroundStyle(mutedSand)

                    if medicationHubSnapshot.hasMedicationData {
                        Text(medicationHubSnapshot.summary)
                            .font(bodyFont(10))
                            .foregroundStyle(medicationHubSnapshot.accentColor)
                    }
                }

                Spacer()

                Button(action: confirmMedication) {
                    Text(medTaken ? "Taken ✓" : "Confirm")
                        .font(bodyFont(12, weight: .medium))
                        .foregroundStyle(medTaken ? sageGreen : mutedSand)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(medTaken ? sageGreen.opacity(0.10) : .clear)
                        .overlay {
                            if !medTaken {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
                            }
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if showMedHint && !medTaken {
                Text("Double-tap anywhere to confirm")
                    .font(bodyFont(11))
                    .foregroundStyle(healTeal.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .modifier(
            LOOKCard(
                background: medTaken ? sageGreen.opacity(0.05) : Color(.systemBackground),
                borderColor: medTaken ? sageGreen.opacity(0.15) : Color.black.opacity(0.06)
            )
        )
        .animation(.easeInOut(duration: 0.4), value: medTaken)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture(count: 2) {
            confirmMedication()
        }
        .onTapGesture {
            guard !medTaken else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showMedHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMedHint = false
                }
            }
        }
    }

    private var streakBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(capsuleColor(for: index))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)
                }
            }

            Text(streakLabel)
                .font(bodyFont(11))
                .foregroundStyle(mutedSand)
                .animation(.easeIn, value: medTaken)
        }
        .padding(.vertical, 2)
        .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06)))
    }

    private var insightCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S INSIGHT")
                    .font(bodyFont(10))
                    .tracking(1.5)
                    .foregroundStyle(sunriseOrange)

                ZStack(alignment: .leading) {
                    Text("\"\(insights[insightIndex])\"")
                        .id(insightIndex)
                        .font(displayFont(17))
                        .italic()
                        .foregroundStyle(darkInk)
                        .lineSpacing(4)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }

                Text("From lived experience, not a textbook.")
                    .font(bodyFont(11))
                    .fontWeight(.light)
                    .foregroundStyle(sunriseOrange)

                Text(patternSummary)
                    .font(bodyFont(10))
                    .foregroundStyle(mutedSand)

                Text(trialMetrics.summary)
                    .font(bodyFont(10))
                    .foregroundStyle(trialMetrics.accentColor)

                if medicationHubSnapshot.hasMedicationData {
                    Text(medicationHubSnapshot.detail)
                        .font(bodyFont(10))
                        .foregroundStyle(medicationHubSnapshot.accentColor)
                }

                Text(patternSnapshot.recommendedAction)
                    .font(bodyFont(10))
                    .foregroundStyle(patternAccentColor)
            }

            Text("\(insightIndex + 1) / 7")
                .font(bodyFont(11))
                .fontWeight(.light)
                .foregroundStyle(mutedSand)
        }
        .overlay(alignment: .bottomTrailing) {
            if insightHintVisible {
                Text("double-tap for next")
                    .font(bodyFont(10))
                    .foregroundStyle(mutedSand.opacity(0.5))
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
            }
        }
        .modifier(LOOKCard(background: sunriseOrange.opacity(0.08), borderColor: sunriseOrange.opacity(0.20)))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                insightIndex = (insightIndex + 1) % insights.count
                insightHintVisible = false
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                dotColor: healTeal,
                pulse: pulseQuestions,
                value: "\(questionCount)",
                label: "Questions",
                subtitle: "Total captured"
            )

            statCard(
                dotColor: sunriseOrange,
                pulse: pulseTrials,
                value: "\(trialCount)",
                label: "Trials",
                subtitle: combinedTrialSubtitle
            )
        }
        .padding(.horizontal, 16)
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAFETY FIRST")
                .font(bodyFont(10))
                .tracking(1.5)
                .foregroundStyle(mutedSand)

            (
                Text("LOOK provides education and support only.")
                    .font(bodyFont(12, weight: .medium))
                + Text(" Always confirm clinical decisions with your transplant team.")
                    .font(bodyFont(12))
                    .fontWeight(.light)
            )
            .foregroundStyle(Color(red: 0.48, green: 0.43, blue: 0.40))
            .lineSpacing(4)
        }
        .modifier(LOOKCard(background: warmDawn, borderColor: Color.black.opacity(0.04)))
    }

    private var greetingInitial: String {
        guard let profile = profiles.first else { return "G" }
        if let first = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).first {
            return String(first).uppercased()
        }
        return "G"
    }

    private var medicationSubtitle: String {
        if let medicationConfirmedAt {
            return "Taken · \(medicationConfirmedAt.formatted(date: .omitted, time: .shortened))"
        }
        return formattedDate()
    }

    private var streakLabel: String {
        let base = "\(max(patternSnapshot.medicationStreak, 0)) days ✦"
        return medTaken ? "\(base)  Medication confirmed" : base
    }

    private var patternSummary: String {
        if trialMetrics.hasStructuredLogs {
            return "\(patternSnapshot.summary) \(trialMetrics.statsSubtitle)"
        }
        return patternSnapshot.summary
    }

    private var combinedTrialSubtitle: String {
        if medicationHubSnapshot.hasMedicationData {
            return "\(trialMetrics.statsSubtitle) · \(medicationHubSnapshot.shortLabel)"
        }
        return trialMetrics.statsSubtitle
    }

    private var patternAccentColor: Color {
        switch patternSnapshot.riskTier {
        case .green:
            return sageGreen
        case .amber:
            return sunriseOrange
        case .red:
            return Color(red: 0.96, green: 0.57, blue: 0.57)
        }
    }

    private func displayFont(_ size: CGFloat) -> Font {
        if UIFont(name: "DM Serif Display", size: size) != nil {
            return .custom("DM Serif Display", size: size)
        }
        return .custom("Georgia", size: size)
    }

    private func bodyFont(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        if UIFont(name: "DM Sans", size: size) != nil {
            return .custom("DM Sans", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    private func submitCheckin(status: CheckinStatus, response: String, color: Color) {
        upsertTodayLog { log in
            log.checkinCompletedAt = .now
            log.checkinStatus = status
            log.updatedAt = .now
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            checkinDone = true
            checkinResponse = response
            checkinColor = color
        }

        refreshDashboardMetrics()
    }

    private func confirmMedication() {
        guard !medTaken else { return }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        let confirmationTime = Date()
        medicationConfirmedAt = confirmationTime

        upsertTodayLog { log in
            log.medicationConfirmedAt = confirmationTime
            log.updatedAt = .now
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            medTaken = true
        }
        showMedHint = false
        refreshDashboardMetrics()
    }

    private func capsuleColor(for index: Int) -> Color {
        if index < 6 {
            return sageGreen
        }
        return medTaken ? sageGreen : sunriseOrange
    }

    private func statCard(
        dotColor: Color,
        pulse: Bool,
        value: String,
        label: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            Text(value)
                .font(displayFont(32))
                .foregroundStyle(dotColor)

            Text(label)
                .font(bodyFont(11))
                .foregroundStyle(mutedSand)

            Text(subtitle)
                .font(bodyFont(10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06)))
    }

    private func checkinChip(
        label: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(bodyFont(11, weight: .medium))
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func refreshDashboardMetrics() {
        questionCount = questions.count
        trialCount = trials.count
        patternSnapshot = PatternEngine.analyze(healthLogs: healthLogs, trials: trials)
        trialMetrics = buildTrialMetrics(from: trials)
        medicationHubSnapshot = loadMedicationHubSnapshot()
    }

    private func buildTrialMetrics(from trials: [DailyTrial]) -> DashboardTrialMetrics {
        let structuredTrials = trials.map(decodeTrial)
        guard !structuredTrials.isEmpty else { return .empty }

        let today = Calendar.current.startOfDay(for: Date())
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        let recentTrials = structuredTrials.filter { trial in
            let day = Calendar.current.startOfDay(for: trial.logDate)
            return day >= sevenDaysAgo && day <= today
        }

        let green = recentTrials.filter { $0.triageLevel == .green }.count
        let amber = recentTrials.filter { $0.triageLevel == .amber }.count
        let red = recentTrials.filter { $0.triageLevel == .red }.count
        let medicationConfirmed = recentTrials.filter(\.medicationConfirmed).count
        let noteCount = recentTrials.filter {
            !$0.doctorNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.doctorNote != "No doctor note"
        }.count

        let summary: String
        if red > 0 {
            summary = "\(red) red log\(red == 1 ? "" : "s") in the last 7 days. Review the most recent symptom notes."
        } else if amber > 0 {
            summary = "\(amber) amber log\(amber == 1 ? "" : "s"), \(medicationConfirmed)/\(max(recentTrials.count, 1)) medication confirmations captured."
        } else {
            summary = "\(green) green log\(green == 1 ? "" : "s"), \(medicationConfirmed)/\(max(recentTrials.count, 1)) medication confirmations, \(noteCount) doctor note\(noteCount == 1 ? "" : "s")."
        }

        let statsSubtitle: String
        if red > 0 {
            statsSubtitle = "\(red) red · \(amber) amber"
        } else if recentTrials.isEmpty {
            statsSubtitle = "Daily logs"
        } else {
            statsSubtitle = "\(green) green · \(medicationConfirmed) meds"
        }

        let accentColor: Color
        if red > 0 {
            accentColor = Color(red: 0.96, green: 0.57, blue: 0.57)
        } else if amber > 0 {
            accentColor = sunriseOrange
        } else {
            accentColor = sageGreen
        }

        return DashboardTrialMetrics(
            hasStructuredLogs: true,
            summary: summary,
            statsSubtitle: statsSubtitle,
            accentColor: accentColor
        )
    }

    private func decodeTrial(_ trial: DailyTrial) -> DashboardDecodedTrial {
        if trial.nextImprovement.hasPrefix("LOOK_TRIAL_V2|") {
            let json = String(trial.nextImprovement.dropFirst("LOOK_TRIAL_V2|".count))
            if let data = json.data(using: .utf8),
               let payload = try? JSONDecoder().decode(DashboardTrialPayload.self, from: data) {
                return DashboardDecodedTrial(
                    logDate: payload.logDate,
                    triageLevel: DashboardTriage(rawValue: payload.triageLevel) ?? fallbackTriage(from: trial.rating),
                    doctorNote: payload.doctorNote,
                    medicationConfirmed: payload.medicationConfirmed
                )
            }
        }

        return DashboardDecodedTrial(
            logDate: trial.createdAt,
            triageLevel: fallbackTriage(from: trial.rating),
            doctorNote: trial.friction,
            medicationConfirmed: false
        )
    }

    private func fallbackTriage(from rating: Int) -> DashboardTriage {
        switch rating {
        case 4...5:
            return .green
        case 3:
            return .amber
        default:
            return .red
        }
    }

    private func loadMedicationHubSnapshot() -> DashboardMedicationSnapshot {
        let defaults = UserDefaults.standard
        let medications = (try? defaults.dashboardDecode([DashboardMedicationRecord].self, forKey: dashboardMedicationKey)) ?? []
        let notificationLog = (try? defaults.dashboardDecode([DashboardNotificationRecord].self, forKey: dashboardNotificationLogKey)) ?? []
        let pendingAcknowledged = defaults.bool(forKey: dashboardPendingAcknowledgedKey)

        guard !medications.isEmpty || !notificationLog.isEmpty || pendingAcknowledged else {
            return .empty
        }

        let activeMedications = medications.filter(\.reminderActive).count
        let acknowledgedCount = notificationLog.filter { $0.status == .acknowledged }.count
        let pendingCount = notificationLog.filter { $0.status == .pending }.count
        let missedCount = notificationLog.filter { $0.status == .missed }.count

        let accentColor: Color
        if pendingCount > 0 && !pendingAcknowledged {
            accentColor = sunriseOrange
        } else if missedCount > 0 {
            accentColor = Color(red: 0.96, green: 0.57, blue: 0.57)
        } else {
            accentColor = healTeal
        }

        let summary = "\(activeMedications) active reminder\(activeMedications == 1 ? "" : "s") · \(acknowledgedCount) acknowledged"
        let detail: String
        if pendingCount > 0 && !pendingAcknowledged {
            detail = "\(pendingCount) reminder\(pendingCount == 1 ? "" : "s") still pending in Medication."
        } else if missedCount > 0 {
            detail = "\(missedCount) missed reminder\(missedCount == 1 ? "" : "s") logged. Review timing today."
        } else {
            detail = "Medication tab is configured for daily follow-through."
        }

        return DashboardMedicationSnapshot(
            hasMedicationData: true,
            summary: summary,
            detail: detail,
            shortLabel: "\(activeMedications) active meds",
            accentColor: accentColor
        )
    }

    private func loadTodayState() {
        guard let todayLog = logForToday() else {
            medTaken = false
            medicationConfirmedAt = nil
            checkinDone = false
            checkinResponse = ""
            checkinColor = .clear
            return
        }

        medTaken = todayLog.medicationConfirmedAt != nil
        medicationConfirmedAt = todayLog.medicationConfirmedAt

        if let status = todayLog.checkinStatus {
            checkinDone = true
            checkinResponse = checkinResponse(for: status)
            checkinColor = checkinColor(for: status)
        } else {
            checkinDone = false
            checkinResponse = ""
            checkinColor = .clear
        }
    }

    private func upsertTodayLog(update: (DailyHealthLog) -> Void) {
        let log = logForToday() ?? DailyHealthLog(dayKey: dayKey(for: Date()))
        if logForToday() == nil {
            modelContext.insert(log)
        }
        update(log)
        try? modelContext.save()
    }

    private func logForToday() -> DailyHealthLog? {
        let todayKey = dayKey(for: Date())
        return healthLogs.first(where: { $0.dayKey == todayKey })
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dateFromDayKey(_ dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }

    private func checkinResponse(for status: CheckinStatus) -> String {
        switch status {
        case .allGood:
            return "Logged. Keep it up. Your consistency matters."
        case .unsure:
            return "Noted. Consider calling your transplant coordinator today."
        case .help:
            return "Please contact your doctor or go to your nearest hospital now."
        }
    }

    private func checkinColor(for status: CheckinStatus) -> Color {
        switch status {
        case .allGood:
            return Color(red: 0.49, green: 0.78, blue: 0.63)
        case .unsure:
            return Color(red: 0.96, green: 0.76, blue: 0.50)
        case .help:
            return Color(red: 0.96, green: 0.57, blue: 0.57)
        }
    }
}

private struct DashboardTrialMetrics {
    let hasStructuredLogs: Bool
    let summary: String
    let statsSubtitle: String
    let accentColor: Color

    static let empty = DashboardTrialMetrics(
        hasStructuredLogs: false,
        summary: "Structured trial insights appear after your first daily log.",
        statsSubtitle: "Daily logs",
        accentColor: mutedSand
    )
}

private struct DashboardMedicationSnapshot {
    let hasMedicationData: Bool
    let summary: String
    let detail: String
    let shortLabel: String
    let accentColor: Color

    static let empty = DashboardMedicationSnapshot(
        hasMedicationData: false,
        summary: "",
        detail: "",
        shortLabel: "",
        accentColor: healTeal
    )
}

private struct DashboardTrialPayload: Codable {
    let triageLevel: String
    let q1: Int
    let q2: Int
    let q3: Int
    let q4: Int
    let doctorNote: String
    let medicationConfirmed: Bool
    let logDate: Date
}

private struct DashboardDecodedTrial {
    let logDate: Date
    let triageLevel: DashboardTriage
    let doctorNote: String
    let medicationConfirmed: Bool
}

private enum DashboardTriage: String {
    case green
    case amber
    case red
}

private struct DashboardMedicationRecord: Codable {
    let id: UUID
    let name: String
    let dose: String
    let times: [String]
    let reminderActive: Bool
}

private struct DashboardNotificationRecord: Codable {
    let id: UUID
    let icon: String
    let title: String
    let time: String
    let status: DashboardNotificationStatus
}

private enum DashboardNotificationStatus: String, Codable {
    case acknowledged
    case missed
    case pending
}

private let dashboardMedicationKey = "triallab.medications"
private let dashboardNotificationLogKey = "triallab.notificationLog"
private let dashboardPendingAcknowledgedKey = "triallab.pendingAcknowledged"

private struct LOOKCard: ViewModifier {
    let background: Color
    let borderColor: Color

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
    }
}

private extension UserDefaults {
    func dashboardDecode<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T {
        guard let data = data(forKey: key) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

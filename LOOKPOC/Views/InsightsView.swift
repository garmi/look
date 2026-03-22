import Charts
import SwiftData
import SwiftUI
import UIKit

private let insightsSunriseOrange = Color(red: 0.91, green: 0.53, blue: 0.23)
private let insightsHealTeal = Color(red: 0.00, green: 0.48, blue: 0.48)
private let insightsSageGreen = Color(red: 0.29, green: 0.49, blue: 0.35)
private let insightsWarmDawn = Color(red: 0.98, green: 0.97, blue: 0.95)
private let insightsDarkInk = Color(red: 0.11, green: 0.11, blue: 0.18)
private let insightsMutedSand = Color(red: 0.71, green: 0.66, blue: 0.60)
private let insightsParchment = Color(red: 0.98, green: 0.98, blue: 0.97)

struct InsightsView: View {
    @Query(sort: \QuestionEntry.createdAt, order: .reverse) private var questions: [QuestionEntry]
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var trials: [DailyTrial]
    @Query(sort: \DailyHealthLog.dayKey, order: .reverse) private var healthLogs: [DailyHealthLog]
    @Query private var profiles: [UserProfile]

    @State private var selectedRange: InsightsRange = .fourteen
    @State private var insightSnapshot: InsightSnapshot = .empty
    @State private var selectedLabMetric: String = "Creatinine"
    @State private var selectedPersonaID: DemoPersonaJourney.ID?
    @State private var selectedDrilldown: InsightDrilldown?
    @State private var sharePayload: SharePayload?

    private let personaJourneys = DemoPersonaLibrary.journeys

    var body: some View {
        VStack(spacing: 0) {
            LOOKNavBar(pageTitle: "Insights", showNotificationDot: false)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    headerSection
                    rangeSelector
                    liveInsightSummary
                    habitTrendSection
                    labTrendSection
                    doctorSummarySection
                    personaSection
                }
                .padding(.bottom, 24)
            }
        }
        .background(insightsParchment.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $selectedDrilldown) { drilldown in
            InsightDrilldownView(drilldown: drilldown)
                .presentationDetents([.large])
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: [payload.url])
        }
        .onAppear {
            refreshInsights()
            if selectedPersonaID == nil {
                selectedPersonaID = personaJourneys.first?.id
            }
        }
        .onChange(of: selectedRange) { _, _ in
            refreshInsights()
        }
        .onChange(of: questions.count) { _, _ in
            refreshInsights()
        }
        .onChange(of: trials.count) { _, _ in
            refreshInsights()
        }
        .onChange(of: healthLogs.count) { _, _ in
            refreshInsights()
        }
        .onChange(of: profiles.first?.updatedAt ?? .distantPast) { _, _ in
            refreshInsights()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshInsights()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Expanded trend view")
                .font(bodyFont(11, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(insightsMutedSand)
                .textCase(.uppercase)

            Text("Patterns for you,\nand a cleaner story for your doctor.")
                .font(displayFont(28))
                .foregroundStyle(insightsDarkInk)
                .lineSpacing(2)

            Text("Use this screen to look beyond today: habits, questions, labs, and how they connect over time.")
                .font(bodyFont(13))
                .foregroundStyle(insightsMutedSand)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var rangeSelector: some View {
        HStack(spacing: 10) {
            ForEach(InsightsRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.title)
                        .font(bodyFont(12, weight: selectedRange == range ? .medium : .light))
                        .foregroundStyle(selectedRange == range ? insightsDarkInk : insightsMutedSand)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(selectedRange == range ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: selectedRange == range ? .black.opacity(0.06) : .clear, radius: 8, y: 3)
                }
            }
        }
        .padding(4)
        .background(Color(red: 0.93, green: 0.91, blue: 0.89))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var liveInsightSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE PATIENT")
                .font(bodyFont(10, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(insightsMutedSand)

            Text(insightSnapshot.patientHeadline)
                .font(displayFont(18))
                .foregroundStyle(insightsDarkInk)

            Text(insightSnapshot.patientBody)
                .font(bodyFont(12))
                .foregroundStyle(insightsMutedSand)
                .lineSpacing(4)

            if !insightSnapshot.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(insightSnapshot.highlights, id: \.self) { highlight in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(insightsHealTeal)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            Text(highlight)
                                .font(bodyFont(11))
                                .foregroundStyle(insightsDarkInk)
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
        .modifier(InsightCard(background: Color.white, borderColor: Color.black.opacity(0.06)))
    }

    private var habitTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("HABIT TRENDS")

            TrendChartCard(
                title: "Medication adherence",
                subtitle: "1 = confirmed, 0 = missed or not logged",
                accentColor: insightsSageGreen,
                points: insightSnapshot.medicationSeries,
                domain: 0...1,
                action: {
                    selectedDrilldown = InsightDrilldown(
                        title: "Medication adherence",
                        subtitle: "Daily confirmations over the selected window.",
                        accentColor: insightsSageGreen,
                        points: insightSnapshot.medicationSeries,
                        domain: 0...1,
                        detailLines: [
                            "A value of 1 means medication was confirmed on that day.",
                            "Missed confirmations are often where patient support should begin."
                        ]
                    )
                }
            )

            TrendChartCard(
                title: "Check-in stability",
                subtitle: "3 = all good, 2 = unsure, 1 = help",
                accentColor: insightsSunriseOrange,
                points: insightSnapshot.checkinSeries,
                domain: 0...3,
                action: {
                    selectedDrilldown = InsightDrilldown(
                        title: "Check-in stability",
                        subtitle: "Mood and symptom confidence across the selected window.",
                        accentColor: insightsSunriseOrange,
                        points: insightSnapshot.checkinSeries,
                        domain: 0...3,
                        detailLines: [
                            "3 means all good, 2 means unsure, and 1 means help.",
                            "Repeated amber or red days usually deserve a tighter follow-up loop."
                        ]
                    )
                }
            )

            TrendChartCard(
                title: "Daily trial score",
                subtitle: "Average rating from the daily log",
                accentColor: insightsHealTeal,
                points: insightSnapshot.trialSeries,
                domain: 0...5,
                action: {
                    selectedDrilldown = InsightDrilldown(
                        title: "Daily trial score",
                        subtitle: "Combined score from symptoms, meds, and emotional state.",
                        accentColor: insightsHealTeal,
                        points: insightSnapshot.trialSeries,
                        domain: 0...5,
                        detailLines: [
                            "This is a composite score from the Trials tab, not a clinical measurement.",
                            "Lower scores are useful context for both patient reflection and doctor prep."
                        ]
                    )
                }
            )

            TrendChartCard(
                title: "Questions captured",
                subtitle: "Questions saved in Ask during this period",
                accentColor: insightsDarkInk,
                points: insightSnapshot.questionSeries,
                domain: 0...max(questionDomainUpperBound, 1),
                action: {
                    selectedDrilldown = InsightDrilldown(
                        title: "Questions captured",
                        subtitle: "How often LOOK is helping convert uncertainty into useful prompts.",
                        accentColor: insightsDarkInk,
                        points: insightSnapshot.questionSeries,
                        domain: 0...max(questionDomainUpperBound, 1),
                        detailLines: [
                            "A higher question count is not necessarily bad.",
                            "Often it means the patient is preparing better for the next appointment."
                        ]
                    )
                }
            )
        }
    }

    private var labTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("LAB FOCUS")

            if insightSnapshot.labSeries.isEmpty {
                emptyCard(message: "Upload one blood report to unlock fuller lab trends here.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(insightSnapshot.labSeries) { series in
                            Button {
                                selectedLabMetric = series.title
                            } label: {
                                Text(series.title)
                                    .font(bodyFont(11, weight: selectedLabMetric == series.title ? .medium : .light))
                                    .foregroundStyle(selectedLabMetric == series.title ? insightsDarkInk : insightsMutedSand)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedLabMetric == series.title ? Color.white : insightsWarmDawn)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedLabMetric == series.title ? color(for: series.status) : Color.black.opacity(0.04), lineWidth: 0.8)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if let series = selectedLabSeries {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(series.title)
                                    .font(displayFont(18))
                                    .foregroundStyle(insightsDarkInk)
                                Text(series.subtitle)
                                    .font(bodyFont(11))
                                    .foregroundStyle(insightsMutedSand)
                            }
                            Spacer()
                            Text(series.points.last.map { formattedValue($0.value) } ?? "-")
                                .font(displayFont(20))
                                .foregroundStyle(color(for: series.status))
                        }

                        TrendChartCard(
                            title: "",
                            subtitle: "",
                            accentColor: color(for: series.status),
                            points: series.points,
                            domain: labDomain(for: series.points),
                            hidesHeader: true,
                            action: {
                                selectedDrilldown = InsightDrilldown(
                                    title: series.title,
                                    subtitle: series.subtitle,
                                    accentColor: color(for: series.status),
                                    points: series.points,
                                    domain: labDomain(for: series.points),
                                    detailLines: [
                                        "This chart is built from uploaded blood reports.",
                                        "LOOK is helping the patient learn their own baseline, not replacing clinical interpretation."
                                    ]
                                )
                            }
                        )
                    }
                    .modifier(InsightCard(background: Color.white, borderColor: color(for: series.status).opacity(0.18)))
                }
            }
        }
    }

    private var doctorSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("FOR DOCTOR")

            VStack(alignment: .leading, spacing: 8) {
                Text(insightSnapshot.doctorHeadline)
                    .font(displayFont(18))
                    .foregroundStyle(insightsDarkInk)

                Text(insightSnapshot.doctorBody)
                    .font(bodyFont(12))
                    .foregroundStyle(insightsMutedSand)
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    Button {
                        if let url = buildDoctorPDF() {
                            sharePayload = SharePayload(url: url)
                        }
                    } label: {
                        Text("Export PDF")
                            .font(bodyFont(11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(insightsDarkInk)
                            .clipShape(Capsule())
                    }

                    Button {
                        selectedDrilldown = InsightDrilldown(
                            title: "Doctor summary",
                            subtitle: "A clinician-facing synthesis from current LOOK data.",
                            accentColor: insightsSunriseOrange,
                            points: insightSnapshot.trialSeries,
                            domain: 0...5,
                            detailLines: doctorExportLines()
                        )
                    } label: {
                        Text("Open full summary")
                            .font(bodyFont(11, weight: .medium))
                            .foregroundStyle(insightsSunriseOrange)
                    }
                }
            }
            .modifier(InsightCard(background: insightsWarmDawn, borderColor: insightsSunriseOrange.opacity(0.14)))
        }
    }

    private var personaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PERSONA COMPARISON")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(personaJourneys) { persona in
                        Button {
                            selectedPersonaID = persona.id
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(persona.name)
                                    .font(displayFont(16))
                                    .foregroundStyle(insightsDarkInk)
                                Text("\(persona.ageLabel) · \(persona.stage.rawValue)")
                                    .font(bodyFont(11, weight: .medium))
                                    .foregroundStyle(insightsHealTeal)
                                Text(persona.headline)
                                    .font(bodyFont(11))
                                    .foregroundStyle(insightsMutedSand)
                                    .lineSpacing(3)
                                Text("\(persona.city.rawValue) · \(persona.language.rawValue)")
                                    .font(bodyFont(10))
                                    .foregroundStyle(insightsMutedSand.opacity(0.8))
                            }
                            .frame(width: 220, alignment: .leading)
                            .padding(16)
                            .background(selectedPersonaID == persona.id ? Color.white : insightsWarmDawn)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(selectedPersonaID == persona.id ? insightsHealTeal.opacity(0.5) : Color.black.opacity(0.04), lineWidth: 0.8)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if let persona = selectedPersona {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comparison view: \(persona.name)")
                        .font(displayFont(18))
                        .foregroundStyle(insightsDarkInk)

                    Text(persona.patientInsight)
                        .font(bodyFont(12))
                        .foregroundStyle(insightsMutedSand)
                        .lineSpacing(4)

                    PersonaTrendComparisonCard(
                        title: "Routine pattern",
                        subtitle: persona.doctorInsight,
                        labels: persona.labels,
                        medicationValues: persona.medicationTrend,
                        trialValues: persona.trialTrend
                    )

                    if let personaLab = persona.labMetrics.first {
                        PersonaMetricCard(metric: personaLab)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Questions this persona would likely ask")
                            .font(bodyFont(11, weight: .medium))
                            .foregroundStyle(insightsDarkInk)
                        ForEach(persona.keyQuestions, id: \.self) { question in
                            Text("• \(question)")
                                .font(bodyFont(11))
                                .foregroundStyle(insightsMutedSand)
                        }
                    }
                }
                .modifier(InsightCard(background: Color.white, borderColor: Color.black.opacity(0.06)))
            }
        }
    }

    private var selectedPersona: DemoPersonaJourney? {
        personaJourneys.first(where: { $0.id == selectedPersonaID }) ?? personaJourneys.first
    }

    private var selectedLabSeries: InsightMetricSeries? {
        insightSnapshot.labSeries.first(where: { $0.title == selectedLabMetric }) ?? insightSnapshot.labSeries.first
    }

    private var questionDomainUpperBound: Double {
        max(insightSnapshot.questionSeries.map(\.value).max() ?? 0, 1)
    }

    private func refreshInsights() {
        let records = HealthRecordStore.loadRecords()
        insightSnapshot = InsightEngine.buildSnapshot(
            range: selectedRange,
            profile: profiles.first,
            questions: questions,
            trials: trials,
            healthLogs: healthLogs,
            records: records
        )

        if selectedLabSeries == nil {
            selectedLabMetric = insightSnapshot.labSeries.first?.title ?? "Creatinine"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(bodyFont(10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(insightsMutedSand)
            .padding(.horizontal, 18)
    }

    private func emptyCard(message: String) -> some View {
        Text(message)
            .font(bodyFont(12))
            .foregroundStyle(insightsMutedSand)
            .modifier(InsightCard(background: Color.white, borderColor: Color.black.opacity(0.06)))
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

    private func color(for status: String) -> Color {
        switch status {
        case "normal":
            return insightsSageGreen
        case "low", "high":
            return insightsSunriseOrange
        case "critical":
            return Color(red: 0.96, green: 0.57, blue: 0.57)
        default:
            return insightsDarkInk
        }
    }

    private func labDomain(for points: [InsightPoint]) -> ClosedRange<Double> {
        let values = points.map(\.value)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        if minimum == maximum {
            return max(0, minimum - 1)...(maximum + 1)
        }
        let padding = max((maximum - minimum) * 0.12, 0.2)
        return (minimum - padding)...(maximum + padding)
    }

    private func formattedValue(_ value: Double) -> String {
        String(format: value.rounded() == value ? "%.0f" : "%.2f", value)
    }

    private func doctorExportLines() -> [String] {
        var lines: [String] = []
        let patientName = profiles.first?.name.isEmpty == false ? profiles.first?.name ?? "Patient" : "Patient"
        lines.append("Patient: \(patientName)")
        lines.append("Range: \(selectedRange.rawValue) days")
        lines.append(insightSnapshot.doctorBody)

        if !insightSnapshot.highlights.isEmpty {
            lines.append("Highlights:")
            lines.append(contentsOf: insightSnapshot.highlights.map { "• \($0)" })
        }

        if let lab = selectedLabSeries {
            lines.append("Lab focus: \(lab.title) — \(lab.subtitle)")
        }

        return lines
    }

    private func buildDoctorPDF() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LOOK-Doctor-Summary.pdf")
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let textColor = UIColor(red: 0.11, green: 0.11, blue: 0.18, alpha: 1)
        let mutedColor = UIColor(red: 0.48, green: 0.43, blue: 0.40, alpha: 1)

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = 36

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "DM Serif Display", size: 24) ?? UIFont(name: "Georgia", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .semibold),
                    .foregroundColor: textColor
                ]
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "DM Sans", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: mutedColor
                ]
                let strongAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "DM Sans", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: textColor
                ]

                NSString(string: "LOOK Doctor Insight Summary").draw(at: CGPoint(x: 36, y: y), withAttributes: titleAttrs)
                y += 42

                let patientName = profiles.first?.name.isEmpty == false ? profiles.first?.name ?? "Patient" : "Patient"
                NSString(string: "Patient: \(patientName)").draw(at: CGPoint(x: 36, y: y), withAttributes: strongAttrs)
                y += 20
                NSString(string: "Range: \(selectedRange.rawValue) days").draw(at: CGPoint(x: 36, y: y), withAttributes: bodyAttrs)
                y += 28

                y = drawWrapped(text: insightSnapshot.doctorHeadline, y: y, width: bounds.width - 72, attributes: strongAttrs) + 10
                y = drawWrapped(text: insightSnapshot.doctorBody, y: y, width: bounds.width - 72, attributes: bodyAttrs) + 16

                for line in doctorExportLines() {
                    y = drawWrapped(text: line, y: y, width: bounds.width - 72, attributes: bodyAttrs) + 8
                }

                y += 12
                let footer = "LOOK supports education and workflow preparation only. Always confirm clinical decisions with your transplant team."
                _ = drawWrapped(text: footer, y: y, width: bounds.width - 72, attributes: bodyAttrs)
            }
            return url
        } catch {
            return nil
        }
    }

    private func drawWrapped(
        text: String,
        y: CGFloat,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        NSString(string: text).draw(
            with: CGRect(x: 36, y: y, width: width, height: rect.height + 4),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return y + rect.height
    }
}

private struct TrendChartCard: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    let points: [InsightPoint]
    let domain: ClosedRange<Double>
    var hidesHeader: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !hidesHeader {
                Text(title)
                    .font(fontBody(13, weight: .medium))
                    .foregroundStyle(insightsDarkInk)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(fontBody(10))
                        .foregroundStyle(insightsMutedSand)
                }
            }

            if points.isEmpty {
                Text("Not enough data yet")
                    .font(fontBody(11))
                    .foregroundStyle(insightsMutedSand)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 160)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(accentColor.opacity(0.12))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(accentColor)
                    .symbolSize(26)
                }
                .chartYScale(domain: domain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color.black.opacity(0.05))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisLabel(for: date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color.black.opacity(0.05))
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .light))
                            .foregroundStyle(insightsMutedSand)
                    }
                }
                .frame(height: 180)
            }
        }
        .modifier(InsightCard(background: Color.white, borderColor: Color.black.opacity(0.06)))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            action?()
        }
    }

    private func fontBody(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        if UIFont(name: "DM Sans", size: size) != nil {
            return .custom("DM Sans", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

private struct PersonaTrendComparisonCard: View {
    let title: String
    let subtitle: String
    let labels: [String]
    let medicationValues: [Double]
    let trialValues: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(fontDisplay(16))
                .foregroundStyle(insightsDarkInk)

            Text(subtitle)
                .font(fontBody(11))
                .foregroundStyle(insightsMutedSand)
                .lineSpacing(3)

            Chart {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    LineMark(
                        x: .value("Day", label),
                        y: .value("Medication", medicationValues[index])
                    )
                    .foregroundStyle(insightsSageGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    LineMark(
                        x: .value("Day", label),
                        y: .value("Trial", trialValues[index])
                    )
                    .foregroundStyle(insightsSunriseOrange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            .chartYScale(domain: 0...5)
            .frame(height: 180)

            HStack(spacing: 14) {
                legendChip(color: insightsSageGreen, label: "Medication")
                legendChip(color: insightsSunriseOrange, label: "Trial score")
            }
        }
        .modifier(InsightCard(background: insightsWarmDawn, borderColor: Color.black.opacity(0.04)))
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(fontBody(10, weight: .medium))
                .foregroundStyle(insightsMutedSand)
        }
    }

    private func fontDisplay(_ size: CGFloat) -> Font {
        if UIFont(name: "DM Serif Display", size: size) != nil {
            return .custom("DM Serif Display", size: size)
        }
        return .custom("Georgia", size: size)
    }

    private func fontBody(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        if UIFont(name: "DM Sans", size: size) != nil {
            return .custom("DM Sans", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }
}

private struct PersonaMetricCard: View {
    let metric: DemoPersonaLabMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.metric)
                .font(fontDisplay(16))
                .foregroundStyle(insightsDarkInk)
            Text("\(metric.unit) · trend sample for comparison")
                .font(fontBody(11))
                .foregroundStyle(insightsMutedSand)

            Chart {
                ForEach(Array(metric.values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Index", index),
                        y: .value(metric.metric, value)
                    )
                    .foregroundStyle(metricColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("Index", index),
                        y: .value(metric.metric, value)
                    )
                    .foregroundStyle(metricColor)
                }
            }
            .frame(height: 160)

            Text(metric.status == "normal" ? "This metric is relatively stable." : "This metric is the main clinician discussion point in this persona.")
                .font(fontBody(10))
                .foregroundStyle(insightsMutedSand)
        }
        .modifier(InsightCard(background: Color.white, borderColor: metricColor.opacity(0.18)))
    }

    private var metricColor: Color {
        switch metric.status {
        case "normal":
            return insightsSageGreen
        case "low", "high":
            return insightsSunriseOrange
        default:
            return Color.red
        }
    }

    private func fontDisplay(_ size: CGFloat) -> Font {
        if UIFont(name: "DM Serif Display", size: size) != nil {
            return .custom("DM Serif Display", size: size)
        }
        return .custom("Georgia", size: size)
    }

    private func fontBody(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        if UIFont(name: "DM Sans", size: size) != nil {
            return .custom("DM Sans", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }
}

private struct InsightCard: ViewModifier {
    let background: Color
    let borderColor: Color

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
    }
}

private struct InsightDrilldown: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let accentColor: Color
    let points: [InsightPoint]
    let domain: ClosedRange<Double>
    let detailLines: [String]
}

private struct InsightDrilldownView: View {
    let drilldown: InsightDrilldown

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.25))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(drilldown.title)
                        .font(fontDisplay(26))
                        .foregroundStyle(insightsDarkInk)

                    Text(drilldown.subtitle)
                        .font(fontBody(12))
                        .foregroundStyle(insightsMutedSand)
                        .lineSpacing(4)

                    TrendChartCard(
                        title: "",
                        subtitle: "",
                        accentColor: drilldown.accentColor,
                        points: drilldown.points,
                        domain: drilldown.domain,
                        hidesHeader: true
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What this means")
                            .font(fontBody(11, weight: .medium))
                            .foregroundStyle(insightsDarkInk)

                        ForEach(drilldown.detailLines, id: \.self) { line in
                            Text("• \(line)")
                                .font(fontBody(11))
                                .foregroundStyle(insightsMutedSand)
                                .lineSpacing(3)
                        }
                    }
                    .modifier(InsightCard(background: insightsWarmDawn, borderColor: drilldown.accentColor.opacity(0.16)))
                }
                .padding(.bottom, 24)
            }
        }
        .background(insightsParchment.ignoresSafeArea())
    }

    private func fontDisplay(_ size: CGFloat) -> Font {
        if UIFont(name: "DM Serif Display", size: size) != nil {
            return .custom("DM Serif Display", size: size)
        }
        return .custom("Georgia", size: size)
    }

    private func fontBody(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        if UIFont(name: "DM Sans", size: size) != nil {
            return .custom("DM Sans", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

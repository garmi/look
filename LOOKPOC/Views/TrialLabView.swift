import SwiftData
import SwiftUI
import UIKit
import UserNotifications

private let sunriseOrange = Color(red: 0.91, green: 0.53, blue: 0.23)
private let healTeal = Color(red: 0.00, green: 0.48, blue: 0.48)
private let sageGreen = Color(red: 0.29, green: 0.49, blue: 0.35)
private let warmDawn = Color(red: 0.98, green: 0.97, blue: 0.95)
private let darkInk = Color(red: 0.11, green: 0.11, blue: 0.18)
private let mutedSand = Color(red: 0.71, green: 0.66, blue: 0.60)
private let parchment = Color(red: 0.98, green: 0.98, blue: 0.97)
private let segmentedBackground = Color(red: 0.93, green: 0.91, blue: 0.89)
private let softCard = Color(red: 0.96, green: 0.94, blue: 0.92)
private let emotionalBrown = Color(red: 0.69, green: 0.47, blue: 0.19)
private let noteSlate = Color(red: 0.42, green: 0.38, blue: 0.44)

struct TrialLabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyTrial.createdAt, order: .reverse) private var storedTrials: [DailyTrial]

    @State private var activeTab: TrialTab = .log
    @State private var selectedDate: Date = Date()
    @State private var showCalendar: Bool = false
    @State private var selectedTriage: TriageLevel = .none
    @State private var q1: Int = 0
    @State private var q2: Int = 0
    @State private var q3: Int = 0
    @State private var q4: Int = 0
    @State private var doctorNote: String = ""
    @State private var medConfirmed: Bool = false
    @State private var medicationConfirmedAt: Date?
    @State private var showRedAlert: Bool = false
    @State private var saveFeedbackVisible: Bool = false

    @State private var pendingAcknowledged: Bool = false
    @State private var medicationName: String = ""
    @State private var medicationDose: String = ""
    @State private var selectedReminderTimes: Set<String> = []
    @State private var customTime: Date = TrialLabView.defaultCustomTime()
    @State private var medications: [Medication] = TrialLabView.defaultMedications
    @State private var notificationLog: [NotificationEntry] = TrialLabView.defaultNotificationLog

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                segmentedControl

                if activeTab == .log {
                    dailyLogTab
                } else {
                    medicationTab
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(parchment.ignoresSafeArea())
        .sheet(isPresented: $showCalendar) {
            calendarSheet
                .presentationDetents([.medium])
        }
        .alert("Please check in with your doctor", isPresented: $showRedAlert) {
            Button("I understand", role: .cancel) {}
        } message: {
            Text("You reported concerning symptoms. Contact your transplant coordinator today.")
        }
        .onAppear {
            loadMedicationPersistence()
            loadTrialState(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            loadTrialState(for: newValue)
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 8) {
            segmentButton(title: "Daily Log", tab: .log)
            segmentButton(title: "Medication", tab: .medication)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(segmentedBackground)
        )
        .padding(.horizontal, 16)
    }

    private var dailyLogTab: some View {
        VStack(spacing: 12) {
            dailyLogHeader
            sunriseBand
            calendarStrip
            reviewStatusCard
            triageSelector
            questionCard1
            questionCard2
            questionCard3
            questionCard4
            questionCard5
            medicationConfirmationCard
            saveButton
            safetyNote
            recentLogsSection
        }
    }

    private var medicationTab: some View {
        VStack(spacing: 12) {
            medicationHeader
            sunriseBand
            pendingNotificationBanner
            addMedicationForm
            medicationListSection
            notificationLogSection
        }
    }

    private var dailyLogHeader: some View {
        HStack(alignment: .top) {
            Text("Daily Trial")
                .font(displayFont(24))
                .foregroundStyle(darkInk)

            Spacer()

            Button {
                showCalendar = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .medium))
                    Text(dateChipFormatter.string(from: selectedDate))
                        .font(bodyFont(11, weight: .medium))
                }
                .foregroundStyle(healTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(healTeal.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var medicationHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Medications")
                .font(displayFont(24))
                .foregroundStyle(darkInk)

            Text("Reminders · Logs · Acknowledgements")
                .font(bodyFont(12))
                .foregroundStyle(mutedSand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
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
        .frame(height: 2)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .opacity(0.5)
        .padding(.horizontal, 16)
    }

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentDays, id: \.self) { day in
                        let indicator = indicatorLevel(for: day)
                        let isToday = calendar.isDateInToday(day)
                        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)

                        Button {
                            selectedDate = day
                        } label: {
                            VStack(spacing: 4) {
                                Text(weekdayFormatter.string(from: day))
                                    .font(bodyFont(9, weight: .medium))
                                Text(dayNumberFormatter.string(from: day))
                                    .font(bodyFont(15, weight: .medium))
                            }
                            .foregroundStyle(dayPillTextColor(isToday: isToday, isSelected: isSelected, indicator: indicator))
                            .frame(width: 42)
                            .padding(.vertical, 10)
                            .background(dayPillBackground(isToday: isToday, isSelected: isSelected, indicator: indicator))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(dayPillBorderColor(isToday: isToday, isSelected: isSelected, indicator: indicator), lineWidth: dayPillBorderWidth(isToday: isToday, isSelected: isSelected, indicator: indicator))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            Button {
                showCalendar = true
            } label: {
                Text("View full calendar →")
                    .font(bodyFont(11, weight: .medium))
                    .foregroundStyle(healTeal)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    private var triageSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overall today")
                .font(bodyFont(10))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(mutedSand)

            HStack(spacing: 10) {
                triageCard(level: .green, emoji: "🟢", label: "Stable")
                triageCard(level: .amber, emoji: "🟠", label: "Watch")
                triageCard(level: .red, emoji: "🔴", label: "Act")
            }
        }
        .padding(.horizontal, 16)
    }

    private var reviewStatusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reviewModeTitle)
                .font(bodyFont(10))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(reviewModeAccent)

            Text(reviewModeMessage)
                .font(bodyFont(12, weight: .medium))
                .foregroundStyle(darkInk)

            Text("Save will \(selectedDecodedTrial == nil ? "create" : "update") the entry for \(logRowDateFormatter.string(from: selectedDate)).")
                .font(bodyFont(11))
                .foregroundStyle(mutedSand)
        }
        .modifier(
            LOOKCard(
                background: reviewModeAccent.opacity(0.08),
                borderColor: reviewModeAccent.opacity(0.18),
                cornerRadius: 16
            )
        )
    }

    private var questionCard1: some View {
        questionScaleCard(
            badgeColor: healTeal,
            index: 1,
            title: "How is your energy today?",
            subtitle: "Compared to your own baseline",
            options: [
                ScaleOption(title: "Very low", tone: .amber, value: 1),
                ScaleOption(title: "Low", tone: .amber, value: 2),
                ScaleOption(title: "Normal", tone: .green, value: 3),
                ScaleOption(title: "Good", tone: .green, value: 4),
                ScaleOption(title: "Great", tone: .green, value: 5)
            ],
            selection: $q1
        )
    }

    private var questionCard2: some View {
        questionScaleCard(
            badgeColor: sunriseOrange,
            index: 2,
            title: "Any new or unusual symptoms?",
            subtitle: "Swelling, reduced urine, pain at transplant site, fever",
            options: [
                ScaleOption(title: "None", tone: .green, value: 1),
                ScaleOption(title: "Mild", tone: .amber, value: 2),
                ScaleOption(title: "Moderate", tone: .amber, value: 3),
                ScaleOption(title: "Concerning", tone: .red, value: 4)
            ],
            selection: $q2,
            onSelect: { value in
                if value == 4 {
                    selectedTriage = .red
                }
            }
        )
    }

    private var questionCard3: some View {
        questionScaleCard(
            badgeColor: sageGreen,
            index: 3,
            title: "Did you take all medications on time?",
            subtitle: "Tacrolimus, mycophenolate, all prescribed",
            options: [
                ScaleOption(title: "Yes all", tone: .green, value: 1),
                ScaleOption(title: "Missed one", tone: .amber, value: 2),
                ScaleOption(title: "Missed several", tone: .red, value: 3),
                ScaleOption(title: "Did not take", tone: .red, value: 4)
            ],
            selection: $q3,
            onSelect: { value in
                if value >= 3 {
                    selectedTriage = .red
                }
            }
        )
    }

    private var questionCard4: some View {
        questionScaleCard(
            badgeColor: emotionalBrown,
            index: 4,
            title: "How is your emotional state?",
            subtitle: "Anxiety and low mood are worth tracking",
            options: [
                ScaleOption(title: "Struggling", tone: .amber, value: 1),
                ScaleOption(title: "Low", tone: .amber, value: 2),
                ScaleOption(title: "Okay", tone: .green, value: 3),
                ScaleOption(title: "Good", tone: .green, value: 4),
                ScaleOption(title: "Positive", tone: .green, value: 5)
            ],
            selection: $q4
        )
    }

    private var questionCard5: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(noteSlate)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text("5")
                            .font(bodyFont(11, weight: .medium))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Anything to note for your doctor?")
                        .font(bodyFont(14, weight: .medium))
                        .foregroundStyle(darkInk)
                    Text("Questions or observations for your next appointment")
                        .font(bodyFont(11))
                        .foregroundStyle(mutedSand)
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    }

                if doctorNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Add a note for your next doctor visit...")
                        .font(bodyFont(12))
                        .foregroundStyle(mutedSand.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $doctorNote)
                    .font(UIFont(name: "DM Sans", size: 12) != nil ? .custom("DM Sans", size: 12) : .system(size: 12, weight: .light, design: .default))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 80)
                    .foregroundStyle(darkInk)
            }
            .frame(minHeight: 92)
        }
        .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06), cornerRadius: 16))
    }

    private var medicationConfirmationCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(medConfirmed ? sageGreen.opacity(0.12) : healTeal.opacity(0.08))
                .frame(width: 34, height: 34)
                .overlay {
                    if medConfirmed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(sageGreen)
                    } else {
                        Text("💊")
                            .font(.system(size: 16))
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Medication taken today")
                    .font(bodyFont(14, weight: .medium))
                    .foregroundStyle(darkInk)

                Text(medConfirmed ? "Confirmed · \(timeFormatter.string(from: medicationConfirmedAt ?? Date()))" : "Tap toggle to confirm")
                    .font(bodyFont(11))
                    .foregroundStyle(mutedSand)
            }

            Spacer()

            Button {
                toggleMedicationConfirmation()
            } label: {
                ZStack(alignment: medConfirmed ? .trailing : .leading) {
                    Capsule()
                        .fill(medConfirmed ? sageGreen : segmentedBackground)
                        .frame(width: 46, height: 26)

                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .padding(2)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: medConfirmed)
            }
            .buttonStyle(.plain)
        }
        .modifier(
            LOOKCard(
                background: medConfirmed ? sageGreen.opacity(0.05) : Color(.systemBackground),
                borderColor: Color.black.opacity(0.06),
                cornerRadius: 16
            )
        )
    }

    private var saveButton: some View {
        Button {
            saveTrial()
        } label: {
            Text(saveFeedbackVisible ? "Saved ✓" : saveButtonTitle)
                .font(bodyFont(14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(saveFeedbackVisible ? sageGreen : darkInk)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .opacity(canSaveTrial ? 1.0 : 0.6)
        .disabled(!canSaveTrial)
    }

    private var safetyNote: some View {
        Text("Red responses should prompt a call to your transplant coordinator today. LOOK supports - it does not diagnose.")
            .font(bodyFont(11))
            .italic()
            .foregroundStyle(mutedSand)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(LOOKCard(background: warmDawn, borderColor: sunriseOrange.opacity(0.15), cornerRadius: 16))
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent logs")
                .font(bodyFont(10))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(mutedSand)
                .padding(.horizontal, 16)

            if decodedTrials.isEmpty {
                Text("No trial logs yet.\nYour first log becomes Day 1\nof your personal health diary.")
                    .font(bodyFont(12))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(mutedSand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06), cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    ForEach(decodedTrials.prefix(12)) { trial in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = trial.logDate
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(trial.triageLevel.color)
                                    .frame(width: 9, height: 9)

                                Text(logRowDateFormatter.string(from: trial.logDate))
                                    .font(bodyFont(12, weight: .medium))
                                    .foregroundStyle(darkInk)

                                if trial.medicationConfirmed {
                                    Text("💊")
                                        .font(.system(size: 13))
                                }

                                Spacer()

                                Text(trial.triageLevel.label)
                                    .font(bodyFont(11, weight: .medium))
                                    .foregroundStyle(trial.triageLevel.color)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(calendar.isDate(trial.logDate, inSameDayAs: selectedDate) ? warmDawn : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06), cornerRadius: 16))
            }
        }
    }

    private var pendingNotificationBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(sunriseOrange.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(sunriseOrange)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tacrolimus due - 8:00 AM")
                    .font(bodyFont(13, weight: .medium))
                    .foregroundStyle(.white)

                Text("Tap Acknowledge to confirm you took it")
                    .font(bodyFont(11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 8)

            Button {
                acknowledgePendingReminder()
            } label: {
                Text(pendingAcknowledged ? "Acknowledged ✓" : "Acknowledge")
                    .font(bodyFont(11, weight: .medium))
                    .foregroundStyle(pendingAcknowledged ? sageGreen : sunriseOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background((pendingAcknowledged ? sageGreen : sunriseOrange).opacity(pendingAcknowledged ? 0.14 : 0.25))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(darkInk)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(pendingAcknowledged ? 0.6 : 1.0)
        .padding(.horizontal, 16)
    }

    private var addMedicationForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            medicationFieldLabel("Medication name")
            TextField("Tacrolimus", text: $medicationName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )

            medicationFieldLabel("Dose")
            TextField("1mg × 2 daily", text: $medicationDose)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )

            medicationFieldLabel("Reminder times")
            HStack(spacing: 8) {
                ForEach(reminderChipOptions, id: \.self) { time in
                    Button {
                        if selectedReminderTimes.contains(time) {
                            selectedReminderTimes.remove(time)
                        } else {
                            selectedReminderTimes.insert(time)
                        }
                    } label: {
                        Text(time)
                            .font(bodyFont(11, weight: .medium))
                            .foregroundStyle(selectedReminderTimes.contains(time) ? .white : mutedSand)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(selectedReminderTimes.contains(time) ? darkInk : softCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            medicationFieldLabel("Custom time")
            DatePicker(
                "",
                selection: $customTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .accentColor(healTeal)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                addMedication()
            } label: {
                Text("Add & Schedule Reminder")
                    .font(bodyFont(13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(healTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06), cornerRadius: 18))
    }

    private var medicationListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(medications.enumerated()), id: \.element.id) { index, medication in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(index.isMultiple(of: 2) ? healTeal : sunriseOrange)
                                .frame(width: 9, height: 9)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(medication.name)
                                    .font(bodyFont(14, weight: .medium))
                                    .foregroundStyle(darkInk)
                                Text(medication.dose)
                                    .font(bodyFont(11))
                                    .foregroundStyle(mutedSand)
                            }
                        }

                        Spacer()

                        Button("Remove") {
                            removeMedication(medication)
                        }
                        .buttonStyle(.plain)
                        .font(bodyFont(11, weight: .medium))
                        .foregroundStyle(sunriseOrange)
                    }

                    FlexibleChipWrap(items: medication.times) { time in
                        Text(time)
                            .font(bodyFont(10, weight: .medium))
                            .foregroundStyle(mutedSand)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(softCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    HStack {
                        Text("Daily reminder")
                            .font(bodyFont(11))
                            .foregroundStyle(mutedSand)
                        Spacer()
                        Text("✓ Active")
                            .font(bodyFont(11, weight: .medium))
                            .foregroundStyle(sageGreen)
                    }
                }
                .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06), cornerRadius: 16))
            }
        }
        .padding(.horizontal, 0)
    }

    private var notificationLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notification log")
                .font(bodyFont(10))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(mutedSand)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(notificationLog) { entry in
                    HStack(spacing: 10) {
                        Text(entry.icon)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                                .font(bodyFont(12, weight: .medium))
                                .foregroundStyle(darkInk)
                            Text(entry.time)
                                .font(bodyFont(11))
                                .foregroundStyle(mutedSand)
                        }

                        Spacer()

                        Text(entry.status.label)
                            .font(bodyFont(10, weight: .medium))
                            .foregroundStyle(entry.status.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(entry.status.color.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
            }
            .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06), cornerRadius: 16))
        }
    }

    private var calendarSheet: some View {
        MonthCalendarSheet(
            selectedDate: $selectedDate,
            loggedTrials: decodedTrials,
            calendar: calendar
        )
    }

    private var decodedTrials: [DecodedTrial] {
        storedTrials
            .map(decodeTrial)
            .sorted { $0.logDate > $1.logDate }
    }

    private var selectedDecodedTrial: DecodedTrial? {
        decodedTrials.first { calendar.isDate($0.logDate, inSameDayAs: selectedDate) }
    }

    private var isPastSelection: Bool {
        calendar.startOfDay(for: selectedDate) < calendar.startOfDay(for: Date())
    }

    private var reviewModeAccent: Color {
        if let selectedDecodedTrial {
            return selectedDecodedTrial.triageLevel.color
        }
        return isPastSelection ? sunriseOrange : healTeal
    }

    private var reviewModeTitle: String {
        if selectedDecodedTrial != nil {
            return isPastSelection ? "Review Mode" : "Today's Saved Log"
        }
        return isPastSelection ? "Backfill Mode" : "Ready To Log"
    }

    private var reviewModeMessage: String {
        if let selectedDecodedTrial {
            return "Loaded \(selectedDecodedTrial.triageLevel.label.lowercased()) log for \(logRowDateFormatter.string(from: selectedDate)). Edit anything and save to overwrite it."
        }
        if isPastSelection {
            return "No saved log for this date yet. You can backfill the day now."
        }
        return "Capture today's status and medication timing in one place."
    }

    private var saveButtonTitle: String {
        if selectedDecodedTrial != nil {
            return "Update Selected Log"
        }
        if isPastSelection {
            return "Save Selected Date"
        }
        return "Save Today's Trial"
    }

    private var recentDays: [Date] {
        (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))
        }
    }

    private var canSaveTrial: Bool {
        selectedTriage != .none && q1 != 0 && q2 != 0 && q3 != 0 && q4 != 0
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private func segmentButton(title: String, tab: TrialTab) -> some View {
        let isActive = activeTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeTab = tab
            }
        } label: {
            Text(title)
                .font(bodyFont(13, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? darkInk : mutedSand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isActive ? Color(.systemBackground) : .clear)
                        .shadow(color: .black.opacity(isActive ? 0.08 : 0), radius: 6, y: 3)
                )
        }
        .buttonStyle(.plain)
    }

    private func triageCard(level: TriageLevel, emoji: String, label: String) -> some View {
        let selected = selectedTriage == level
        let color = level.color

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTriage = level
            }
        } label: {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 24))
                Text(label)
                    .font(bodyFont(10, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(color.opacity(selected ? 0.18 : 0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(selected ? 1.0 : 0.20), lineWidth: selected ? 1.5 : 1.0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func questionScaleCard(
        badgeColor: Color,
        index: Int,
        title: String,
        subtitle: String,
        options: [ScaleOption],
        selection: Binding<Int>,
        onSelect: ((Int) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(badgeColor)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text("\(index)")
                            .font(bodyFont(11, weight: .medium))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(bodyFont(14, weight: .medium))
                        .foregroundStyle(darkInk)
                    Text(subtitle)
                        .font(bodyFont(11))
                        .foregroundStyle(mutedSand)
                }
            }

            FlexibleChipWrap(items: options) { option in
                Button {
                    selection.wrappedValue = option.value
                    onSelect?(option.value)
                } label: {
                    Text(option.title)
                        .font(bodyFont(11, weight: .medium))
                        .foregroundStyle(scaleButtonTextColor(option: option, selected: selection.wrappedValue == option.value))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(scaleButtonBackground(option: option, selected: selection.wrappedValue == option.value))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .modifier(LOOKCard(background: Color(.systemBackground), borderColor: Color.black.opacity(0.06), cornerRadius: 16))
    }

    private func scaleButtonBackground(option: ScaleOption, selected: Bool) -> Color {
        guard selected else { return softCard }
        switch option.tone {
        case .green:
            return sageGreen.opacity(0.15)
        case .amber:
            return sunriseOrange.opacity(0.15)
        case .red:
            return Color.red.opacity(0.12)
        }
    }

    private func scaleButtonTextColor(option: ScaleOption, selected: Bool) -> Color {
        guard selected else { return mutedSand }
        switch option.tone {
        case .green:
            return sageGreen
        case .amber:
            return sunriseOrange
        case .red:
            return .red
        }
    }

    private func toggleMedicationConfirmation() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            medConfirmed.toggle()
        }
        medicationConfirmedAt = medConfirmed ? Date() : nil
    }

    private func saveTrial() {
        guard canSaveTrial else { return }

        let payload = TrialPayload(
            triageLevel: selectedTriage.rawValue,
            q1: q1,
            q2: q2,
            q3: q3,
            q4: q4,
            doctorNote: doctorNote.trimmingCharacters(in: .whitespacesAndNewlines),
            medicationConfirmed: medConfirmed,
            logDate: calendar.startOfDay(for: selectedDate)
        )

        let summary = summaryText(for: payload)
        let encodedPayload = encodePayload(payload)
        let createdAt = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let rating = derivedRating(for: payload)

        if let existing = storedTrials.first(where: { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }) {
            existing.createdAt = createdAt
            existing.updatedAt = .now
            existing.rating = rating
            existing.whatWorked = summary
            existing.friction = payload.doctorNote.isEmpty ? "No doctor note" : payload.doctorNote
            existing.nextImprovement = encodedPayload
        } else {
            let entry = DailyTrial(
                createdAt: createdAt,
                updatedAt: .now,
                rating: rating,
                whatWorked: summary,
                friction: payload.doctorNote.isEmpty ? "No doctor note" : payload.doctorNote,
                nextImprovement: encodedPayload
            )
            modelContext.insert(entry)
        }

        try? modelContext.save()

        withAnimation(.easeInOut(duration: 0.2)) {
            saveFeedbackVisible = true
        }

        if selectedTriage == .red {
            showRedAlert = true
        }

        if selectedDecodedTrial != nil || isPastSelection {
            loadTrialState(for: selectedDate)
        } else {
            resetDailyLogFields()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                saveFeedbackVisible = false
            }
        }
    }

    private func loadTrialState(for date: Date) {
        guard let trial = storedTrials.first(where: { calendar.isDate($0.createdAt, inSameDayAs: date) }) else {
            resetDailyLogFields()
            return
        }

        let decoded = decodeTrial(trial)
        selectedTriage = decoded.triageLevel
        q1 = decoded.q1
        q2 = decoded.q2
        q3 = decoded.q3
        q4 = decoded.q4
        doctorNote = decoded.doctorNote == "No doctor note" ? "" : decoded.doctorNote
        medConfirmed = decoded.medicationConfirmed
        medicationConfirmedAt = decoded.medicationConfirmed ? trial.updatedAt : nil
    }

    private func resetDailyLogFields() {
        selectedTriage = .none
        q1 = 0
        q2 = 0
        q3 = 0
        q4 = 0
        doctorNote = ""
        medConfirmed = false
        medicationConfirmedAt = nil
    }

    private func indicatorLevel(for date: Date) -> TrialIndicator {
        guard let trial = decodedTrials.first(where: { calendar.isDate($0.logDate, inSameDayAs: date) }) else {
            return .none
        }

        switch trial.triageLevel {
        case .green:
            return .green
        case .amber, .red:
            return .amber
        case .none:
            return .none
        }
    }

    private func dayPillBackground(isToday: Bool, isSelected: Bool, indicator: TrialIndicator) -> Color {
        if isToday {
            return darkInk
        }
        if isSelected {
            return warmDawn
        }
        return Color(.systemBackground)
    }

    private func dayPillBorderColor(isToday: Bool, isSelected: Bool, indicator: TrialIndicator) -> Color {
        if isToday {
            return darkInk
        }
        if isSelected {
            return darkInk.opacity(0.18)
        }
        switch indicator {
        case .green:
            return sageGreen
        case .amber:
            return sunriseOrange
        case .none:
            return Color.black.opacity(0.06)
        }
    }

    private func dayPillBorderWidth(isToday: Bool, isSelected: Bool, indicator: TrialIndicator) -> CGFloat {
        if isToday || isSelected || indicator != .none {
            return 1
        }
        return 0.5
    }

    private func dayPillTextColor(isToday: Bool, isSelected: Bool, indicator: TrialIndicator) -> Color {
        if isToday {
            return .white
        }
        switch indicator {
        case .green:
            return sageGreen
        case .amber:
            return sunriseOrange
        case .none:
            return isSelected ? darkInk : mutedSand
        }
    }

    private func medicationFieldLabel(_ text: String) -> some View {
        Text(text)
            .font(bodyFont(10))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(mutedSand)
    }

    private func addMedication() {
        let trimmedName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var times = Array(selectedReminderTimes).sorted { reminderSortOrder($0) < reminderSortOrder($1) }
        let customTimeString = timeFormatter.string(from: customTime)
        if !times.contains(customTimeString) {
            times.append(customTimeString)
        }

        let medication = Medication(
            name: trimmedName,
            dose: medicationDose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Dose not set" : medicationDose.trimmingCharacters(in: .whitespacesAndNewlines),
            times: times
        )

        scheduleNotifications(for: medication)
        medications.insert(medication, at: 0)
        saveMedicationPersistence()

        medicationName = ""
        medicationDose = ""
        selectedReminderTimes = []
        customTime = TrialLabView.defaultCustomTime()
    }

    private func removeMedication(_ medication: Medication) {
        cancelNotifications(for: medication)
        medications.removeAll { $0.id == medication.id }
        saveMedicationPersistence()
    }

    private func acknowledgePendingReminder() {
        guard !pendingAcknowledged else { return }

        pendingAcknowledged = true
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        notificationLog.insert(
            NotificationEntry(
                icon: "💊",
                title: "Tacrolimus 8:00 AM - Acknowledged",
                time: timeFormatter.string(from: Date()),
                status: .acknowledged
            ),
            at: 0
        )
        saveMedicationPersistence()
    }

    private func scheduleNotifications(for medication: Medication) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                submitNotificationRequests(for: medication)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    submitNotificationRequests(for: medication)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func submitNotificationRequests(for medication: Medication) {
        let center = UNUserNotificationCenter.current()

        for time in medication.times {
            guard let date = notificationTimeFormatter.date(from: time) else { continue }
            let components = calendar.dateComponents([.hour, .minute], from: date)

            let content = UNMutableNotificationContent()
            content.title = "LOOK - Medication Reminder"
            content.body = "Time to take \(medication.name). Tap to acknowledge."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = notificationIdentifier(for: medication, time: time)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelNotifications(for medication: Medication) {
        let identifiers = medication.times.map { notificationIdentifier(for: medication, time: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func notificationIdentifier(for medication: Medication, time: String) -> String {
        "med-\(medication.id.uuidString)-\(time.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: ":", with: "-"))"
    }

    private func loadMedicationPersistence() {
        let defaults = UserDefaults.standard
        if let medicationsData = defaults.data(forKey: Self.medicationsKey),
           let decoded = try? JSONDecoder().decode([Medication].self, from: medicationsData) {
            medications = decoded
        }

        if let logData = defaults.data(forKey: Self.notificationLogKey),
           let decoded = try? JSONDecoder().decode([NotificationEntry].self, from: logData) {
            notificationLog = decoded
        }

        pendingAcknowledged = defaults.bool(forKey: Self.pendingAcknowledgedKey)
    }

    private func saveMedicationPersistence() {
        let defaults = UserDefaults.standard
        if let medicationsData = try? JSONEncoder().encode(medications) {
            defaults.set(medicationsData, forKey: Self.medicationsKey)
        }
        if let logData = try? JSONEncoder().encode(notificationLog) {
            defaults.set(logData, forKey: Self.notificationLogKey)
        }
        defaults.set(pendingAcknowledged, forKey: Self.pendingAcknowledgedKey)
    }

    private func summaryText(for payload: TrialPayload) -> String {
        "Triage \(payload.triageLevel) · energy \(payload.q1) · symptoms \(payload.q2) · meds \(payload.q3) · emotion \(payload.q4)"
    }

    private func encodePayload(_ payload: TrialPayload) -> String {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return payload.doctorNote
        }
        return "LOOK_TRIAL_V2|\(json)"
    }

    private func decodeTrial(_ trial: DailyTrial) -> DecodedTrial {
        if trial.nextImprovement.hasPrefix("LOOK_TRIAL_V2|") {
            let json = String(trial.nextImprovement.dropFirst("LOOK_TRIAL_V2|".count))
            if let data = json.data(using: .utf8),
               let payload = try? JSONDecoder().decode(TrialPayload.self, from: data) {
                return DecodedTrial(
                    id: trial.id,
                    logDate: payload.logDate,
                    triageLevel: TriageLevel(rawValue: payload.triageLevel) ?? fallbackTriage(from: trial.rating),
                    q1: payload.q1,
                    q2: payload.q2,
                    q3: payload.q3,
                    q4: payload.q4,
                    doctorNote: payload.doctorNote,
                    medicationConfirmed: payload.medicationConfirmed
                )
            }
        }

        return DecodedTrial(
            id: trial.id,
            logDate: trial.createdAt,
            triageLevel: fallbackTriage(from: trial.rating),
            q1: 0,
            q2: 0,
            q3: 0,
            q4: 0,
            doctorNote: trial.friction,
            medicationConfirmed: false
        )
    }

    private func fallbackTriage(from rating: Int) -> TriageLevel {
        switch rating {
        case 4...5:
            return .green
        case 3:
            return .amber
        default:
            return .red
        }
    }

    private func derivedRating(for payload: TrialPayload) -> Int {
        var score = 0
        score += payload.q1
        score += max(1, 5 - payload.q2)
        score += max(1, 5 - payload.q3)
        score += payload.q4

        switch TriageLevel(rawValue: payload.triageLevel) ?? .amber {
        case .green:
            score += 4
        case .amber:
            score += 2
        case .red:
            score += 0
        case .none:
            score += 0
        }

        let normalized = Int(round(Double(score) / 4.2))
        return min(max(normalized, 1), 5)
    }

    private func reminderSortOrder(_ time: String) -> Int {
        reminderChipOptions.firstIndex(of: time) ?? Int.max
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

    private static func defaultCustomTime() -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static let medicationsKey = "triallab.medications"
    private static let notificationLogKey = "triallab.notificationLog"
    private static let pendingAcknowledgedKey = "triallab.pendingAcknowledged"

    private static let defaultMedications: [Medication] = [
        Medication(name: "Tacrolimus", dose: "1mg × 2 daily", times: ["8:00 AM", "8:00 PM"]),
        Medication(name: "Mycophenolate", dose: "500mg × 2 daily", times: ["9:00 AM", "9:00 PM"])
    ]

    private static let defaultNotificationLog: [NotificationEntry] = [
        NotificationEntry(icon: "💊", title: "Tacrolimus 8:00 AM - Acknowledged", time: "8:03 AM", status: .acknowledged),
        NotificationEntry(icon: "💊", title: "Mycophenolate 9:00 AM - Acknowledged", time: "9:01 AM", status: .acknowledged),
        NotificationEntry(icon: "🔔", title: "Tacrolimus 8:00 PM - Pending", time: "Due at 8:00 PM", status: .pending)
    ]

    private let reminderChipOptions = ["8:00 AM", "12:00 PM", "6:00 PM", "9:00 PM"]
}

private enum TrialTab {
    case log
    case medication
}

private enum TriageLevel: String, Codable {
    case none
    case green
    case amber
    case red

    var color: Color {
        switch self {
        case .none:
            return mutedSand
        case .green:
            return sageGreen
        case .amber:
            return sunriseOrange
        case .red:
            return .red
        }
    }

    var label: String {
        switch self {
        case .none:
            return "None"
        case .green:
            return "Green"
        case .amber:
            return "Amber"
        case .red:
            return "Red"
        }
    }
}

private enum Tone {
    case green
    case amber
    case red
}

private enum TrialIndicator {
    case none
    case green
    case amber
}

private struct ScaleOption: Identifiable, Hashable {
    let title: String
    let tone: Tone
    let value: Int

    var id: Int { value }
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

private struct DecodedTrial: Identifiable {
    let id: UUID
    let logDate: Date
    let triageLevel: TriageLevel
    let q1: Int
    let q2: Int
    let q3: Int
    let q4: Int
    let doctorNote: String
    let medicationConfirmed: Bool
}

private struct Medication: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var dose: String
    var times: [String]
    var reminderActive: Bool = true
}

private enum NotifStatus: String, Codable {
    case acknowledged
    case missed
    case pending

    var color: Color {
        switch self {
        case .acknowledged:
            return sageGreen
        case .missed:
            return sunriseOrange
        case .pending:
            return healTeal
        }
    }

    var label: String {
        switch self {
        case .acknowledged:
            return "Acknowledged"
        case .missed:
            return "Missed"
        case .pending:
            return "Pending"
        }
    }
}

private struct NotificationEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var icon: String
    var title: String
    var time: String
    var status: NotifStatus
}

private struct MonthCalendarSheet: View {
    @Binding var selectedDate: Date
    let loggedTrials: [DecodedTrial]
    let calendar: Calendar
    @Environment(\.dismiss) private var dismiss

    private var monthDates: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthStartWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday,
              let daysRange = calendar.range(of: .day, in: .month, for: selectedDate) else {
            return []
        }

        let leadingBlanks = max(0, monthStartWeekday - calendar.firstWeekday)
        let normalizedLeading = leadingBlanks >= 0 ? leadingBlanks : leadingBlanks + 7

        var items = Array(repeating: CalendarDay.empty, count: normalizedLeading)
        items.append(contentsOf: daysRange.compactMap { day -> CalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else {
                return nil
            }
            return CalendarDay(date: date)
        })
        return items
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(monthYearFormatter.string(from: selectedDate))
                .font(displayFont(20))
                .foregroundStyle(darkInk)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            Text("Green = logged · Orange = amber · Tap to review")
                .font(bodyFont(11))
                .foregroundStyle(mutedSand)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(bodyFont(10, weight: .medium))
                        .foregroundStyle(mutedSand)
                }

                ForEach(monthDates) { day in
                    if let date = day.date {
                        calendarDayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 38)
                    }
                }
            }
            .padding(.horizontal, 16)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(bodyFont(13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(darkInk)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(parchment.ignoresSafeArea())
    }

    private func calendarDayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > calendar.startOfDay(for: Date())
        let indicator = indicatorLevel(for: date)

        return Button {
            guard !isFuture else { return }
            selectedDate = date
            dismiss()
        } label: {
            Text(dayNumberFormatter.string(from: date))
                .font(bodyFont(13, weight: .medium))
                .foregroundStyle(dayTextColor(isToday: isToday, isFuture: isFuture, indicator: indicator))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(isToday ? darkInk : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(dayBorderColor(isToday: isToday, indicator: indicator), lineWidth: dayBorderWidth(isToday: isToday, indicator: indicator))
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func indicatorLevel(for date: Date) -> TrialIndicator {
        guard let trial = loggedTrials.first(where: { calendar.isDate($0.logDate, inSameDayAs: date) }) else {
            return .none
        }

        switch trial.triageLevel {
        case .green:
            return .green
        case .amber, .red:
            return .amber
        case .none:
            return .none
        }
    }

    private func dayTextColor(isToday: Bool, isFuture: Bool, indicator: TrialIndicator) -> Color {
        if isToday {
            return .white
        }
        if isFuture {
            return mutedSand
        }
        switch indicator {
        case .green:
            return sageGreen
        case .amber:
            return sunriseOrange
        case .none:
            return darkInk
        }
    }

    private func dayBorderColor(isToday: Bool, indicator: TrialIndicator) -> Color {
        if isToday {
            return darkInk
        }
        switch indicator {
        case .green:
            return sageGreen
        case .amber:
            return sunriseOrange
        case .none:
            return Color.black.opacity(0.06)
        }
    }

    private func dayBorderWidth(isToday: Bool, indicator: TrialIndicator) -> CGFloat {
        if isToday || indicator != .none {
            return 1
        }
        return 0.5
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let prefix = Array(symbols[(calendar.firstWeekday - 1)...])
        let suffix = Array(symbols[..<(calendar.firstWeekday - 1)])
        return prefix + suffix
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
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?

    init(date: Date) {
        self.date = date
    }

    private init() {
        date = nil
    }

    static let empty = CalendarDay()
}

private struct FlexibleChipWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

private struct LOOKCard: ViewModifier {
    let background: Color
    let borderColor: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 0.5)
            }
            .padding(.horizontal, 16)
    }
}

private let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    return formatter
}()

private let dayNumberFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter
}()

private let dateChipFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMM"
    return formatter
}()

private let logRowDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, d MMM"
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
}()

private let notificationTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a"
    return formatter
}()

private let monthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
}()

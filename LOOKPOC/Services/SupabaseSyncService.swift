import Foundation
import SwiftData

enum SupabaseSyncError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase URL, anon key, and workspace ID are required."
        case .invalidURL:
            return "The Supabase URL is invalid."
        case let .httpError(statusCode, body):
            return "Supabase sync failed (\(statusCode)): \(body)"
        }
    }
}

struct SyncResult {
    let uploadedRows: Int
    let downloadedRows: Int
    let syncedAt: Date
    let message: String
}

@MainActor
enum SupabaseSyncService {
    static func sync(
        modelContext: ModelContext,
        settings: SyncSettings,
        profiles: [UserProfile],
        questions: [QuestionEntry],
        trials: [DailyTrial],
        healthLogs: [DailyHealthLog]
    ) async throws -> SyncResult {
        guard settings.isConfigured else {
            throw SupabaseSyncError.missingConfiguration
        }

        let client = try SupabaseRESTClient(settings: settings)
        let remoteBundle = try await client.fetchWorkspaceBundle(workspaceID: settings.workspaceID)
        let downloadedRows = mergeRemoteBundle(
            remoteBundle,
            modelContext: modelContext,
            localProfile: profiles.first,
            localQuestions: questions,
            localTrials: trials,
            localHealthLogs: healthLogs
        )

        try modelContext.save()

        let uploadedRows = try await client.upsertWorkspaceBundle(
            WorkspaceBundle(
                profile: profiles.first.map { .fromLocal($0, workspaceID: settings.workspaceID) },
                questions: questions.map { .fromLocal($0, workspaceID: settings.workspaceID) },
                trials: trials.map { .fromLocal($0, workspaceID: settings.workspaceID) },
                healthLogs: healthLogs.map { .fromLocal($0, workspaceID: settings.workspaceID) }
            )
        )

        settings.lastSyncAt = .now
        settings.lastSyncMessage = "Synced \(uploadedRows) upload row(s), merged \(downloadedRows) remote row(s)."
        try modelContext.save()

        return SyncResult(
            uploadedRows: uploadedRows,
            downloadedRows: downloadedRows,
            syncedAt: settings.lastSyncAt ?? .now,
            message: settings.lastSyncMessage
        )
    }

    private static func mergeRemoteBundle(
        _ bundle: WorkspaceBundle,
        modelContext: ModelContext,
        localProfile: UserProfile?,
        localQuestions: [QuestionEntry],
        localTrials: [DailyTrial],
        localHealthLogs: [DailyHealthLog]
    ) -> Int {
        var mergedCount = 0

        if let remoteProfile = bundle.profile {
            if let localProfile {
                if remoteProfile.updatedAt > localProfile.updatedAt {
                    localProfile.name = remoteProfile.name
                    localProfile.stageRaw = remoteProfile.stageRaw
                    localProfile.cityRaw = remoteProfile.cityRaw
                    localProfile.languageRaw = remoteProfile.languageRaw
                    localProfile.createdAt = remoteProfile.createdAt
                    localProfile.updatedAt = remoteProfile.updatedAt
                    mergedCount += 1
                }
            } else {
                modelContext.insert(remoteProfile.toLocal())
                mergedCount += 1
            }
        }

        let questionIndex = Dictionary(uniqueKeysWithValues: localQuestions.map { ($0.id.uuidString.lowercased(), $0) })
        for remoteQuestion in bundle.questions {
            if let local = questionIndex[remoteQuestion.id] {
                if remoteQuestion.updatedAt > local.updatedAt {
                    local.question = remoteQuestion.question
                    local.createdAt = remoteQuestion.createdAt
                    local.updatedAt = remoteQuestion.updatedAt
                    local.categoryRaw = remoteQuestion.categoryRaw
                    local.aiSummary = remoteQuestion.aiSummary
                    local.recommendation = remoteQuestion.recommendation
                    local.safetyNote = remoteQuestion.safetyNote
                    local.escalateToHuman = remoteQuestion.escalateToHuman
                    local.resolved = remoteQuestion.resolved
                    local.userNotes = remoteQuestion.userNotes
                    mergedCount += 1
                }
            } else {
                modelContext.insert(remoteQuestion.toLocal())
                mergedCount += 1
            }
        }

        let trialIndex = Dictionary(uniqueKeysWithValues: localTrials.map { ($0.id.uuidString.lowercased(), $0) })
        for remoteTrial in bundle.trials {
            if let local = trialIndex[remoteTrial.id] {
                if remoteTrial.updatedAt > local.updatedAt {
                    local.createdAt = remoteTrial.createdAt
                    local.updatedAt = remoteTrial.updatedAt
                    local.rating = remoteTrial.rating
                    local.whatWorked = remoteTrial.whatWorked
                    local.friction = remoteTrial.friction
                    local.nextImprovement = remoteTrial.nextImprovement
                    mergedCount += 1
                }
            } else {
                modelContext.insert(remoteTrial.toLocal())
                mergedCount += 1
            }
        }

        let healthLogIndex = Dictionary(uniqueKeysWithValues: localHealthLogs.map { ($0.dayKey, $0) })
        for remoteHealthLog in bundle.healthLogs {
            if let local = healthLogIndex[remoteHealthLog.dayKey] {
                if remoteHealthLog.updatedAt > local.updatedAt {
                    local.createdAt = remoteHealthLog.createdAt
                    local.updatedAt = remoteHealthLog.updatedAt
                    local.medicationConfirmedAt = remoteHealthLog.medicationConfirmedAt
                    local.checkinCompletedAt = remoteHealthLog.checkinCompletedAt
                    local.checkinStatusRaw = remoteHealthLog.checkinStatusRaw
                    mergedCount += 1
                }
            } else {
                modelContext.insert(remoteHealthLog.toLocal())
                mergedCount += 1
            }
        }

        return mergedCount
    }
}

private struct WorkspaceBundle {
    let profile: RemoteProfileRow?
    let questions: [RemoteQuestionRow]
    let trials: [RemoteTrialRow]
    let healthLogs: [RemoteHealthLogRow]
}

private struct SupabaseRESTClient {
    private let settings: SyncSettings
    private let session: URLSession

    init(settings: SyncSettings, session: URLSession = .shared) throws {
        guard URL(string: settings.supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else {
            throw SupabaseSyncError.invalidURL
        }
        self.settings = settings
        self.session = session
    }

    func fetchWorkspaceBundle(workspaceID: String) async throws -> WorkspaceBundle {
        async let profileRows: [RemoteProfileRow] = fetchRows(
            table: "look_profiles",
            workspaceID: workspaceID,
            orderBy: "updated_at.desc",
            limit: 1
        )
        async let questions: [RemoteQuestionRow] = fetchRows(
            table: "look_questions",
            workspaceID: workspaceID,
            orderBy: "updated_at.desc"
        )
        async let trials: [RemoteTrialRow] = fetchRows(
            table: "look_trials",
            workspaceID: workspaceID,
            orderBy: "updated_at.desc"
        )
        async let healthLogs: [RemoteHealthLogRow] = fetchRows(
            table: "look_health_logs",
            workspaceID: workspaceID,
            orderBy: "updated_at.desc"
        )

        return try await WorkspaceBundle(
            profile: profileRows.first,
            questions: questions,
            trials: trials,
            healthLogs: healthLogs
        )
    }

    func upsertWorkspaceBundle(_ bundle: WorkspaceBundle) async throws -> Int {
        var uploadedRows = 0

        if let profile = bundle.profile {
            uploadedRows += try await upsertRows(
                table: "look_profiles",
                rows: [profile],
                conflictColumns: "workspace_id"
            )
        }

        if !bundle.questions.isEmpty {
            uploadedRows += try await upsertRows(
                table: "look_questions",
                rows: bundle.questions,
                conflictColumns: "workspace_id,id"
            )
        }

        if !bundle.trials.isEmpty {
            uploadedRows += try await upsertRows(
                table: "look_trials",
                rows: bundle.trials,
                conflictColumns: "workspace_id,id"
            )
        }

        if !bundle.healthLogs.isEmpty {
            uploadedRows += try await upsertRows(
                table: "look_health_logs",
                rows: bundle.healthLogs,
                conflictColumns: "workspace_id,day_key"
            )
        }

        return uploadedRows
    }

    private func fetchRows<T: Decodable>(
        table: String,
        workspaceID: String,
        orderBy: String,
        limit: Int? = nil
    ) async throws -> [T] {
        var components = try baseComponents(for: table)
        var queryItems = [
            URLQueryItem(name: "workspace_id", value: "eq.\(workspaceID)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: orderBy)
        ]
        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw SupabaseSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try jsonDecoder.decode([T].self, from: data)
    }

    private func upsertRows<T: Encodable>(
        table: String,
        rows: [T],
        conflictColumns: String
    ) async throws -> Int {
        var components = try baseComponents(for: table)
        components.queryItems = [
            URLQueryItem(name: "on_conflict", value: conflictColumns)
        ]

        guard let url = components.url else {
            throw SupabaseSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try jsonEncoder.encode(rows)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return rows.count
    }

    private func baseComponents(for table: String) throws -> URLComponents {
        guard let baseURL = URL(string: settings.supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SupabaseSyncError.invalidURL
        }

        let url = baseURL
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
            .appendingPathComponent(table)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SupabaseSyncError.invalidURL
        }

        return components
    }

    private func applyHeaders(to request: inout URLRequest) {
        let key = settings.anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else { return }
        guard (200...299).contains(response.statusCode) else {
            throw SupabaseSyncError.httpError(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
    }

    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = iso8601Formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return decoder
    }

    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601Formatter.string(from: date))
        }
        return encoder
    }

    private var iso8601Formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

private struct RemoteProfileRow: Codable {
    let workspace_id: String
    let id: String
    let name: String
    let stageRaw: String
    let cityRaw: String
    let languageRaw: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case workspace_id
        case id
        case name
        case stageRaw = "stage_raw"
        case cityRaw = "city_raw"
        case languageRaw = "language_raw"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func fromLocal(_ profile: UserProfile, workspaceID: String) -> Self {
        .init(
            workspace_id: workspaceID,
            id: profile.id.uuidString.lowercased(),
            name: profile.name,
            stageRaw: profile.stageRaw,
            cityRaw: profile.cityRaw,
            languageRaw: profile.languageRaw,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }

    func toLocal() -> UserProfile {
        UserProfile(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            stage: PatientStage(rawValue: stageRaw) ?? .ckd,
            city: CityChoice(rawValue: cityRaw) ?? .bengaluru,
            language: LanguageChoice(rawValue: languageRaw) ?? .english,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct RemoteQuestionRow: Codable {
    let workspace_id: String
    let id: String
    let question: String
    let createdAt: Date
    let updatedAt: Date
    let categoryRaw: String
    let aiSummary: String
    let recommendation: String
    let safetyNote: String
    let escalateToHuman: Bool
    let resolved: Bool
    let userNotes: String

    enum CodingKeys: String, CodingKey {
        case workspace_id
        case id
        case question
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case categoryRaw = "category_raw"
        case aiSummary = "ai_summary"
        case recommendation
        case safetyNote = "safety_note"
        case escalateToHuman = "escalate_to_human"
        case resolved
        case userNotes = "user_notes"
    }

    static func fromLocal(_ question: QuestionEntry, workspaceID: String) -> Self {
        .init(
            workspace_id: workspaceID,
            id: question.id.uuidString.lowercased(),
            question: question.question,
            createdAt: question.createdAt,
            updatedAt: question.updatedAt,
            categoryRaw: question.categoryRaw,
            aiSummary: question.aiSummary,
            recommendation: question.recommendation,
            safetyNote: question.safetyNote,
            escalateToHuman: question.escalateToHuman,
            resolved: question.resolved,
            userNotes: question.userNotes
        )
    }

    func toLocal() -> QuestionEntry {
        let entry = QuestionEntry(
            id: UUID(uuidString: id) ?? UUID(),
            question: question,
            createdAt: createdAt,
            updatedAt: updatedAt,
            category: TriageCategory(rawValue: categoryRaw) ?? .general,
            aiSummary: aiSummary,
            recommendation: recommendation,
            safetyNote: safetyNote,
            escalateToHuman: escalateToHuman
        )
        entry.resolved = resolved
        entry.userNotes = userNotes
        return entry
    }
}

private struct RemoteTrialRow: Codable {
    let workspace_id: String
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let rating: Int
    let whatWorked: String
    let friction: String
    let nextImprovement: String

    enum CodingKeys: String, CodingKey {
        case workspace_id
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case rating
        case whatWorked = "what_worked"
        case friction
        case nextImprovement = "next_improvement"
    }

    static func fromLocal(_ trial: DailyTrial, workspaceID: String) -> Self {
        .init(
            workspace_id: workspaceID,
            id: trial.id.uuidString.lowercased(),
            createdAt: trial.createdAt,
            updatedAt: trial.updatedAt,
            rating: trial.rating,
            whatWorked: trial.whatWorked,
            friction: trial.friction,
            nextImprovement: trial.nextImprovement
        )
    }

    func toLocal() -> DailyTrial {
        DailyTrial(
            id: UUID(uuidString: id) ?? UUID(),
            createdAt: createdAt,
            updatedAt: updatedAt,
            rating: rating,
            whatWorked: whatWorked,
            friction: friction,
            nextImprovement: nextImprovement
        )
    }
}

private struct RemoteHealthLogRow: Codable {
    let workspace_id: String
    let dayKey: String
    let createdAt: Date
    let updatedAt: Date
    let medicationConfirmedAt: Date?
    let checkinCompletedAt: Date?
    let checkinStatusRaw: String?

    enum CodingKeys: String, CodingKey {
        case workspace_id
        case dayKey = "day_key"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case medicationConfirmedAt = "medication_confirmed_at"
        case checkinCompletedAt = "checkin_completed_at"
        case checkinStatusRaw = "checkin_status_raw"
    }

    static func fromLocal(_ log: DailyHealthLog, workspaceID: String) -> Self {
        .init(
            workspace_id: workspaceID,
            dayKey: log.dayKey,
            createdAt: log.createdAt,
            updatedAt: log.updatedAt,
            medicationConfirmedAt: log.medicationConfirmedAt,
            checkinCompletedAt: log.checkinCompletedAt,
            checkinStatusRaw: log.checkinStatusRaw
        )
    }

    func toLocal() -> DailyHealthLog {
        DailyHealthLog(
            dayKey: dayKey,
            createdAt: createdAt,
            updatedAt: updatedAt,
            medicationConfirmedAt: medicationConfirmedAt,
            checkinCompletedAt: checkinCompletedAt,
            checkinStatus: checkinStatusRaw.flatMap(CheckinStatus.init(rawValue:))
        )
    }
}

import SwiftUI

struct DirectoryView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Knowledge Seed Pack") {
                    ForEach(KnowledgeRepository.articles) { article in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title)
                                .font(.subheadline.weight(.semibold))
                            Text("\(article.pillar) • \(article.language.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Doctor Directory (POC)") {
                    ForEach(KnowledgeRepository.doctors) { doctor in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(doctor.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(doctor.specialty) • \(doctor.city.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Languages: \(doctor.languages.map(\.rawValue).joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(doctor.notes)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Community Groups") {
                    ForEach(KnowledgeRepository.communityGroups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name)
                                .font(.subheadline.weight(.semibold))
                            Text(group.focus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Directory")
        }
    }
}

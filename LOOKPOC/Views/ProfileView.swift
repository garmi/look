import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            List {
                if let profile = profiles.first {
                    Section("Your Context") {
                        TextField(
                            "Name (optional)",
                            text: Binding(
                                get: { profile.name },
                                set: { newValue in
                                    profile.name = newValue
                                    profile.updatedAt = .now
                                    try? modelContext.save()
                                }
                            )
                        )

                        Picker(
                            "Stage",
                            selection: Binding(
                                get: { profile.stage },
                                set: { newValue in
                                    profile.stage = newValue
                                    try? modelContext.save()
                                }
                            )
                        ) {
                            ForEach(PatientStage.allCases) { stage in
                                Text(stage.rawValue).tag(stage)
                            }
                        }

                        Picker(
                            "City",
                            selection: Binding(
                                get: { profile.city },
                                set: { newValue in
                                    profile.city = newValue
                                    try? modelContext.save()
                                }
                            )
                        ) {
                            ForEach(CityChoice.allCases) { city in
                                Text(city.rawValue).tag(city)
                            }
                        }

                        Picker(
                            "Language",
                            selection: Binding(
                                get: { profile.language },
                                set: { newValue in
                                    profile.language = newValue
                                    try? modelContext.save()
                                }
                            )
                        ) {
                            ForEach(LanguageChoice.allCases) { language in
                                Text(language.rawValue).tag(language)
                            }
                        }
                    }

                    Section("Safety") {
                        Text("This POC is for educational guidance, workflow trials, and self-tracking. It is not medical advice.")
                            .font(.footnote)
                        Text("For urgent symptoms, use emergency care immediately.")
                            .font(.footnote)
                    }
                } else {
                    Text("Preparing profile...")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                if profiles.isEmpty {
                    modelContext.insert(UserProfile())
                    try? modelContext.save()
                }
            }
        }
    }
}

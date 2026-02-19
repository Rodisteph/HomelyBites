import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        Form {
            if let user = session.appUser {
                Section("Mon profil") {
                    HStack {
                        Text("Nom")
                        Spacer()
                        Text(user.displayName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Role")
                        Spacer()
                        Text(user.role.displayTitle)
                            .foregroundStyle(.secondary)
                    }

                    if user.isHost {
                        HStack {
                            Text("Niveau")
                            Spacer()
                            Text(user.chefLevel.displayTitle)
                                .foregroundStyle(.secondary)
                        }

                        NavigationLink("Modifier le profil host") {
                            ProfileView()
                        }
                    }
                }
            }

            Section {
                Button("Se deconnecter", role: .destructive) {
                    session.signOut()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

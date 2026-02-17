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
                        Text(user.fullName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Role")
                        Spacer()
                        Text(user.role.displayTitle)
                            .foregroundStyle(.secondary)
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

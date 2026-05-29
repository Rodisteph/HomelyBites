import SwiftUI

struct SettingsView: View {
    @Environment(SessionViewModel.self) private var session

    var body: some View {
        Form {
            if let user = session.appUser {
                Section("Mon profil") {
                    row("Nom",  value: user.fullName)
                    row("Rôle", value: user.role.displayTitle)
                }
            }
            Section {
                Button("Se déconnecter", role: .destructive) {
                    session.signOut()
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

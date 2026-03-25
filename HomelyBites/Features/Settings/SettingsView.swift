import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject private var session: SessionViewModel

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

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
                        Text("Rôle")
                        Spacer()
                        Text(user.role.displayTitle)
                            .foregroundStyle(.secondary)
                    }

                    if user.isHost {
                        HStack {
                            Text("Niveau")
                            Spacer()
                            Text(ChefLevel(rawValue: user.chefLevel ?? "")?.displayTitle ?? "Non défini")
                                .foregroundStyle(.secondary)
                        }

                        NavigationLink("Modifier le profil hôte") {
                            ProfileView()
                        }
                    }
                }
            }

            Section("Informations légales") {
                NavigationLink("Politique de confidentialité") {
                    PrivacyPolicyView()
                }
                NavigationLink("Conditions générales d'utilisation") {
                    TermsOfServiceView()
                }
            }

            Section {
                Button("Se déconnecter", role: .destructive) {
                    session.signOut()
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Supprimer mon compte")
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("Cette action est irréversible. Toutes vos données seront supprimées.")
                    .font(.bodySmall)
            }
        }
        .navigationTitle("Réglages")
        .alert("Supprimer votre compte ?", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer définitivement", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Cette action est irréversible. Votre profil, vos repas et vos données seront supprimés définitivement.")
        }
        .alert(
            "Erreur",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(deleteError ?? "") }
        )
    }

    private func deleteAccount() async {
        guard let uid = session.appUser?.id else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            // Delete Firestore data first
            let firestoreService = FirestoreService()
            try await firestoreService.deleteUserData(uid: uid)

            // Delete Firebase Auth account
            try await Auth.auth().currentUser?.delete()

            // Sign out (clears local session)
            session.signOut()
        } catch {
            deleteError = "Impossible de supprimer le compte : \(error.localizedDescription)"
        }
    }
}

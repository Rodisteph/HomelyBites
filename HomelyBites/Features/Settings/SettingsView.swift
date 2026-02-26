import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var isDeletingAccount = false
    @State private var showDeleteAccountConfirmation = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let functionsService = CloudFunctionsService()

    var body: some View {
        Form {
            if let user = session.appUser {
                profileSection(user: user)
            }

            Section("Legal") {
                Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                Link("Terms of Use", destination: AppConfig.termsOfUseURL)
            }

            if let successMessage {
                Section {
                    Text(successMessage)
                        .foregroundStyle(HBColors.success)
                        .font(HBTypography.body(size: 14, weight: .medium))
                }
            }

            Section("Account") {
                Button("Sign out", role: .destructive) {
                    session.signOut()
                }

                Button(
                    isDeletingAccount ? "Deleting account..." : "Delete account",
                    role: .destructive
                ) {
                    showDeleteAccountConfirmation = true
                }
                .disabled(isDeletingAccount)
            }
        }
        .navigationTitle("Settings")
        .alert(
            "Delete account?",
            isPresented: $showDeleteAccountConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            .disabled(isDeletingAccount)
        } message: {
            Text("This action is permanent and will remove your profile and related data.")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(errorMessage ?? "")
            }
        )
    }

    @ViewBuilder
    private func profileSection(user: AppUser) -> some View {
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

            if user.isHost {
                HStack {
                    Text("Niveau")
                    Spacer()
                    Text(ChefLevel(rawValue: user.chefLevel ?? "")?.displayTitle ?? "Non defini")
                        .foregroundStyle(.secondary)
                }

                NavigationLink("Modifier le profil host") {
                    ProfileView()
                }
            }
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        successMessage = nil

        do {
            try await functionsService.deleteAccountAndData()
            successMessage = "Account deleted."
            session.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

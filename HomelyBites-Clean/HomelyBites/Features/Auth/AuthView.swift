import SwiftUI

// 🔑 Déplacé depuis Core/Services/Auth/ → Features/Auth/
struct AuthView: View {
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(AuthViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.mode == .signUp {
                    TextField("Nom complet", text: $viewModel.fullName)
                        .textInputAutocapitalization(.words)
                    Picker("Rôle", selection: $viewModel.selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.displayTitle).tag(role)
                        }
                    }
                }

                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Mot de passe", text: $viewModel.password)

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isLoading {
                        HStack { ProgressView(); Text("Veuillez patienter...") }
                    } else {
                        Text(viewModel.mode.actionTitle)
                    }
                }
                .disabled(viewModel.isLoading)
            }
            .navigationTitle("HomelyBites")
            .errorAlert(message: $viewModel.errorMessage)
        }
    }
}

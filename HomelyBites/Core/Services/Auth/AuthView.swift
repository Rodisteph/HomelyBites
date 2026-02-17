import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()

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

                    Picker("Role", selection: $viewModel.selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.displayTitle).tag(role)
                        }
                    }
                }

                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                SecureField("Mot de passe", text: $viewModel.password)

                Button {
                    Task {
                        await viewModel.submit()
                    }
                } label: {
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Veuillez patienter...")
                        }
                    } else {
                        Text(viewModel.mode.actionTitle)
                    }
                }
                .disabled(viewModel.isLoading)
            }
            .navigationTitle("HomelyBites")
            .alert(
                "Erreur",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) {}
                },
                message: {
                    Text(viewModel.errorMessage ?? "")
                }
            )
        }
    }
}

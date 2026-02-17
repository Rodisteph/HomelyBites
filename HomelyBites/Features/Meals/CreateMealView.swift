import SwiftUI

struct CreateMealView: View {
    @Environment(\.dismiss) private var dismiss
    let host: AppUser

    @StateObject private var viewModel = CreateMealViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Titre", text: $viewModel.title)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Prix (EUR)", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                    Stepper("Portions disponibles: \(viewModel.availablePortions)", value: $viewModel.availablePortions, in: 1...500)
                    TextField("Tags (comma separated)", text: $viewModel.tagsText)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Creer un meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createMeal(host: host)
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Publier")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
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
            .onChange(of: viewModel.didSave) { _, didSave in
                if didSave {
                    dismiss()
                }
            }
        }
    }
}

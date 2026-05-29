import SwiftUI

struct CreateMealView: View {
    @Environment(\.dismiss) private var dismiss
    let host: AppUser
    @State private var viewModel = CreateMealViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Titre", text: $viewModel.title)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Prix (EUR)", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                    Stepper(
                        "Portions disponibles : \(viewModel.availablePortions)",
                        value: $viewModel.availablePortions, in: 1...500
                    )
                    TextField("Tags (séparés par virgule)", text: $viewModel.tagsText)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Créer un repas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.createMeal(host: host) }
                    } label: {
                        if viewModel.isSaving { ProgressView() }
                        else { Text("Publier") }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .errorAlert(message: $viewModel.errorMessage)
            .onChange(of: viewModel.didSave) { _, saved in
                if saved { dismiss() }
            }
        }
    }
}

import SwiftUI
import PhotosUI
import UIKit

struct CreateMealView: View {
    @Environment(\.dismiss) private var dismiss
    let host: AppUser

    @StateObject private var viewModel = CreateMealViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoPreview: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo du repas") {
                    HStack(spacing: 16) {
                        if let selectedPhotoPreview {
                            Image(uiImage: selectedPhotoPreview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: HBTheme.Radius.thumb))
                        } else {
                            RoundedRectangle(cornerRadius: HBTheme.Radius.thumb)
                                .fill(HBTheme.Colors.skeleton)
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(HBTheme.Colors.textSecondary)
                                }
                        }

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            Text("Choisir une photo")
                        }
                    }
                }

                Section("Informations") {
                    TextField("Titre", text: $viewModel.title)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Prix (EUR)", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                    Stepper("Portions : \(viewModel.availablePortions)", value: $viewModel.availablePortions, in: 1...500)
                    TextField("Tags (separes par des virgules)", text: $viewModel.tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section("Service") {
                    Picker("Mode", selection: $viewModel.serviceMode) {
                        ForEach(MealServiceMode.allCases) { mode in
                            Text(mode.displayTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !host.hasAcceptedHaccp {
                    Section("HACCP") {
                        Text("Publication bloquee : valide d'abord les regles HACCP dans ton profil.")
                            .foregroundStyle(HBTheme.Colors.danger)
                            .font(HBTheme.Font.body(14))
                    }
                }
            }
            .navigationTitle("Creer un repas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.createMeal(host: host) }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Publier")
                                .font(HBTheme.Font.body(16, weight: .semibold))
                                .foregroundStyle(HBTheme.Colors.primary)
                        }
                    }
                    .disabled(viewModel.isSaving || !host.hasAcceptedHaccp)
                }
            }
            .alert(
                "Erreur",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(viewModel.errorMessage ?? "") }
            )
            .onChange(of: viewModel.didSave) { _, didSave in
                if didSave { dismiss() }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    guard let data = try? await newValue?.loadTransferable(type: Data.self) else {
                        viewModel.errorMessage = "Impossible de lire la photo."
                        return
                    }
                    selectedPhotoPreview = UIImage(data: data)
                    viewModel.setSelectedMealPhotoData(data)
                }
            }
        }
    }
}

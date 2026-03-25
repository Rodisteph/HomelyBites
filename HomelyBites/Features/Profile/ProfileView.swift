import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let uploadTitle = viewModel.isUploadingPhoto ? "Upload..." : "Choisir une photo"

        Form {
            Section("Photo") {
                HStack(spacing: 16) {
                    profilePhoto
                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            Text(uploadTitle)
                        }
                        .disabled(viewModel.isUploadingPhoto)

                        Text("JPG/PNG, max 5MB")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            Section("Profil hôte") {
                TextField("Nom affiché", text: $viewModel.fullName)
                    .appTextFieldStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                    TextEditor(text: $viewModel.bio)
                        .frame(minHeight: 120)
                        .appTextFieldStyle()
                    HStack {
                        Spacer()
                        Text("\(viewModel.bio.count)/280")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Picker("Niveau de chef", selection: $viewModel.chefLevel) {
                    ForEach(ChefLevel.allCases) { level in
                        Text(level.displayTitle).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            if session.appUser?.role == .host {
                Section("HACCP") {
                    if viewModel.hasAcceptedHaccp {
                        Text("Validation HACCP active (version \(viewModel.haccpVersion)).")
                            .font(.caption)
                            .foregroundStyle(AppColors.success)
                    } else {
                        Text("Validation HACCP requise avant publication d'un repas.")
                            .font(.caption)
                            .foregroundStyle(AppColors.warning)
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.hasAcceptedHaccp },
                        set: { newValue in
                            if newValue && !viewModel.hasAcceptedHaccp {
                                Task {
                                    await viewModel.acknowledgeHaccp()
                                    await session.refreshUserProfile()
                                }
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("J'ai pris connaissance des règles de sécurité alimentaire (HACCP)")
                                .font(.bodyMedium)
                            if viewModel.isAcknowledgingHaccp {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Validation en cours...")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    .disabled(viewModel.isAcknowledgingHaccp)
                }
            }

            Section {
                Button {
                    guard let uid = session.appUser?.id else { return }
                    Task {
                        await viewModel.save(userId: uid)
                        await session.refreshUserProfile()
                    }
                } label: {
                    if viewModel.isSaving {
                        HStack {
                            ProgressView()
                            Text("Enregistrement...")
                        }
                    } else {
                        Text("Sauvegarder")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isSaving))
                .disabled(viewModel.isSaving || viewModel.isUploadingPhoto)
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    Text(successMessage)
                        .foregroundStyle(AppColors.success)
                }
            }
        }
        .navigationTitle("Profil hôte")
        .onAppear {
            if let user = session.appUser {
                viewModel.load(from: user)
            }
        }
        .onChange(of: session.appUser?.id) { _, _ in
            if let user = session.appUser {
                viewModel.load(from: user)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let uid = session.appUser?.id else { return }
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else {
                    viewModel.errorMessage = "Impossible de lire la photo selectionnee."
                    return
                }
                await viewModel.uploadPhoto(userId: uid, data: data)
                await session.refreshUserProfile()
            }
        }
        .onChange(of: viewModel.bio) { _, newValue in
            if newValue.count > 280 {
                viewModel.bio = String(newValue.prefix(280))
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
    }

    @ViewBuilder
    private var profilePhoto: some View {
        if let selectedImage = viewModel.selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
        } else if let urlString = viewModel.photoURL,
                  let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: 84, height: 84)
            .background(AppColors.surface, in: Circle())
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

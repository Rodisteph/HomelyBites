import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    private let functionsService = CloudFunctionsService()

    var body: some View {
        ScrollView {
            VStack(spacing: HBTheme.Spacing.l) {
                profileHeader
                if session.appUser?.isHost == true { hostSection }
                accountSection
                legalSection
                dangerZone
            }
            .padding(.horizontal, HBTheme.Spacing.screen)
            .padding(.vertical, HBTheme.Spacing.m)
        }
        .hbBackground()
        .navigationTitle("Profil")
        .onAppear {
            if let user = session.appUser { viewModel.load(from: user) }
        }
        .onChange(of: session.appUser?.id) { _, _ in
            if let user = session.appUser { viewModel.load(from: user) }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let uid = session.appUser?.id else { return }
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else {
                    viewModel.errorMessage = "Impossible de lire la photo."
                    return
                }
                await viewModel.uploadPhoto(userId: uid, data: data)
                await session.refreshUserProfile()
            }
        }
        .onChange(of: viewModel.bio) { _, newValue in
            if newValue.count > 280 { viewModel.bio = String(newValue.prefix(280)) }
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
        .alert(
            "Supprimer le compte ?",
            isPresented: $showDeleteAccountConfirmation
        ) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                Task { await deleteAccount() }
            }
            .disabled(isDeletingAccount)
        } message: {
            Text("Cette action est irreversible. Ton profil et tes donnees seront supprimes.")
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

    // MARK: - Profile Header

    private var profileHeader: some View {
        CardContainer {
            HStack(spacing: 16) {
                profilePhoto

                VStack(alignment: .leading, spacing: 6) {
                    if let user = session.appUser {
                        Text(user.fullName)
                            .font(HBTheme.Font.title(22))
                            .foregroundStyle(HBTheme.Colors.text)
                        Badge(
                            label: user.role.displayTitle,
                            kind: user.isHost ? .info : .neutral
                        )
                    }
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Text(viewModel.isUploadingPhoto ? "Upload..." : "Modifier la photo")
                            .font(HBTheme.Font.label(13, weight: .semibold))
                            .foregroundStyle(HBTheme.Colors.primary)
                    }
                    .disabled(viewModel.isUploadingPhoto)
                }

                Spacer()
            }
        }
    }

    // MARK: - Host Section

    private var hostSection: some View {
        CardContainer {
            Text("Profil host").hbTitle()

            VStack(alignment: .leading, spacing: HBTheme.Spacing.s) {
                Text("Nom affiche")
                    .font(HBTheme.Font.label(13, weight: .semibold))
                    .foregroundStyle(HBTheme.Colors.textSecondary)
                TextField("Nom", text: $viewModel.fullName)
                    .hbInputStyle()
            }

            VStack(alignment: .leading, spacing: HBTheme.Spacing.s) {
                HStack {
                    Text("Bio")
                        .font(HBTheme.Font.label(13, weight: .semibold))
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                    Spacer()
                    Text("\(viewModel.bio.count)/280")
                        .font(HBTheme.Font.caption)
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
                TextEditor(text: $viewModel.bio)
                    .frame(minHeight: 100)
                    .font(HBTheme.Font.body(15))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: HBTheme.Radius.input, style: .continuous)
                            .fill(HBTheme.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HBTheme.Radius.input, style: .continuous)
                            .stroke(HBTheme.Colors.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: HBTheme.Spacing.s) {
                Text("Niveau de chef")
                    .font(HBTheme.Font.label(13, weight: .semibold))
                    .foregroundStyle(HBTheme.Colors.textSecondary)
                Picker("Niveau", selection: $viewModel.chefLevel) {
                    ForEach(ChefLevel.allCases) { level in
                        Text(level.displayTitle).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            // HACCP
            if viewModel.hasAcceptedHaccp {
                HStack(spacing: HBTheme.Spacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(HBTheme.Colors.success)
                    Text("HACCP valide (v\(viewModel.haccpVersion))")
                        .font(HBTheme.Font.body(14, weight: .medium))
                        .foregroundStyle(HBTheme.Colors.success)
                }
            } else {
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
                    Text("J'accepte les regles HACCP")
                        .font(HBTheme.Font.body(14))
                }
                .tint(HBTheme.Colors.primary)
                .disabled(viewModel.isAcknowledgingHaccp)
            }

            PrimaryButton(
                title: "Sauvegarder",
                icon: "checkmark",
                isLoading: viewModel.isSaving,
                isDisabled: viewModel.isSaving || viewModel.isUploadingPhoto
            ) {
                guard let uid = session.appUser?.id else { return }
                Task {
                    await viewModel.save(userId: uid)
                    await session.refreshUserProfile()
                }
            }

            if let msg = viewModel.successMessage {
                HStack(spacing: HBTheme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HBTheme.Colors.success)
                    Text(msg)
                        .font(HBTheme.Font.body(14))
                        .foregroundStyle(HBTheme.Colors.success)
                }
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        CardContainer {
            Text("Compte").hbTitle()

            if let user = session.appUser {
                infoRow(label: "Role", value: user.role.displayTitle)
                if user.isHost {
                    infoRow(label: "Niveau", value: ChefLevel(rawValue: user.chefLevel ?? "")?.displayTitle ?? "Non defini")
                }
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        CardContainer {
            Text("Legal").hbTitle()

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                HStack {
                    Text("Politique de confidentialite")
                        .font(HBTheme.Font.body(15))
                        .foregroundStyle(HBTheme.Colors.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
            }

            NavigationLink {
                TermsOfServiceView()
            } label: {
                HStack {
                    Text("Conditions d'utilisation")
                        .font(HBTheme.Font.body(15))
                        .foregroundStyle(HBTheme.Colors.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: HBTheme.Spacing.s) {
            SecondaryButton(title: "Se deconnecter", icon: "rectangle.portrait.and.arrow.right") {
                session.signOut()
            }

            Button {
                showDeleteAccountConfirmation = true
            } label: {
                Text(isDeletingAccount ? "Suppression..." : "Supprimer mon compte")
                    .font(HBTheme.Font.body(14, weight: .medium))
                    .foregroundStyle(HBTheme.Colors.danger)
            }
            .disabled(isDeletingAccount)
            .padding(.bottom, HBTheme.Spacing.xl)
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var profilePhoto: some View {
        Group {
            if let selectedImage = viewModel.selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = viewModel.photoURL,
                      let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().stroke(HBTheme.Colors.border, lineWidth: 1))
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle().fill(HBTheme.Colors.skeleton)
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundStyle(HBTheme.Colors.textSecondary)
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HBTheme.Font.body(15))
                .foregroundStyle(HBTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(HBTheme.Font.body(15, weight: .medium))
                .foregroundStyle(HBTheme.Colors.text)
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await functionsService.deleteAccountAndData()
            session.signOut()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

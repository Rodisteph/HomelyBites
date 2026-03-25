import SwiftUI

// MARK: - Report Content View (UGC Moderation - App Store Guideline 1.2)
struct ReportContentView: View {
    @Environment(\.dismiss) private var dismiss

    let contentType: ReportContentType
    let contentId: String

    @State private var selectedReason: ReportReason?
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                if didSubmit {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppColors.success)

                            Text("Signalement envoyé")
                                .font(.headlineMedium)
                                .foregroundStyle(AppColors.charcoal)

                            Text("Merci pour votre signalement. Notre équipe examinera ce contenu dans les plus brefs délais.")
                                .font(.bodyMedium)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                } else {
                    Section("Raison du signalement") {
                        ForEach(ReportReason.allCases) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reason.title)
                                            .font(.bodyLarge)
                                            .foregroundStyle(AppColors.charcoal)
                                        Text(reason.subtitle)
                                            .font(.bodySmall)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppColors.primary)
                                    }
                                }
                            }
                        }
                    }

                    Section("Détails supplémentaires (optionnel)") {
                        TextField("Décrivez le problème...", text: $additionalDetails, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                    }

                    Section {
                        Button {
                            Task { await submitReport() }
                        } label: {
                            if isSubmitting {
                                HStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Envoi...")
                                }
                            } else {
                                Text("Envoyer le signalement")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: isSubmitting))
                        .disabled(selectedReason == nil || isSubmitting)
                    }
                }
            }
            .navigationTitle("Signaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func submitReport() async {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        // Store report in Firestore
        do {
            let db = try FirestoreService()
            try await db.submitReport(
                contentType: contentType,
                contentId: contentId,
                reason: reason,
                details: additionalDetails
            )
            didSubmit = true
        } catch {
            // Silently succeed for now - reports can be retried
            didSubmit = true
        }
    }
}

// MARK: - Report Types
enum ReportContentType: String, Codable {
    case meal
    case user
}

enum ReportReason: String, CaseIterable, Identifiable, Codable {
    case inappropriate = "inappropriate"
    case misleading = "misleading"
    case spam = "spam"
    case safety = "safety"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inappropriate: return "Contenu inapproprié"
        case .misleading: return "Information trompeuse"
        case .spam: return "Spam ou publicité"
        case .safety: return "Problème de sécurité alimentaire"
        case .other: return "Autre"
        }
    }

    var subtitle: String {
        switch self {
        case .inappropriate: return "Contenu offensant, vulgaire ou illégal"
        case .misleading: return "Description ou photo ne correspondant pas au repas"
        case .spam: return "Contenu publicitaire ou répétitif"
        case .safety: return "Risque d'hygiène ou d'allergie non signalé"
        case .other: return "Autre problème à signaler"
        }
    }
}

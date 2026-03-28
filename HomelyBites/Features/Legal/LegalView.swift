import SwiftUI

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Politique de confidentialité")
                    .font(HBTheme.Font.display(32))
                    .foregroundStyle(HBTheme.Colors.text)

                Group {
                    legalSection(
                        title: "1. Données collectées",
                        content: """
                        HomelyBites collecte les données suivantes :
                        • Nom complet et adresse e-mail (inscription)
                        • Photo de profil (optionnelle)
                        • Données de localisation (affichage des repas à proximité)
                        • Informations de paiement (traitées par Stripe, non stockées sur nos serveurs)
                        • Contenu publié (repas, descriptions, photos)
                        """
                    )

                    legalSection(
                        title: "2. Utilisation des données",
                        content: """
                        Vos données sont utilisées pour :
                        • Créer et gérer votre compte
                        • Permettre les transactions entre clients et hôtes
                        • Afficher les repas à proximité via la géolocalisation
                        • Traiter les paiements de manière sécurisée via Stripe
                        • Améliorer nos services
                        """
                    )

                    legalSection(
                        title: "3. Partage des données",
                        content: """
                        Vos données ne sont jamais vendues. Elles sont partagées uniquement avec :
                        • Stripe (traitement des paiements)
                        • Firebase/Google Cloud (hébergement sécurisé)
                        • Les autres utilisateurs (nom et photo de profil visibles)
                        """
                    )

                    legalSection(
                        title: "4. Sécurité",
                        content: """
                        Nous utilisons le chiffrement SSL/TLS, l'authentification Firebase, \
                        et les standards de sécurité PCI DSS (via Stripe) pour protéger vos données.
                        """
                    )

                    legalSection(
                        title: "5. Vos droits (RGPD)",
                        content: """
                        Conformément au RGPD, vous disposez des droits suivants :
                        • Droit d'accès à vos données
                        • Droit de rectification
                        • Droit à l'effacement (suppression de compte)
                        • Droit à la portabilité
                        • Droit d'opposition

                        Pour exercer vos droits : contact@homelybites.app
                        """
                    )

                    legalSection(
                        title: "6. Conservation des données",
                        content: """
                        Vos données sont conservées tant que votre compte est actif. \
                        En cas de suppression de compte, vos données personnelles sont supprimées sous 30 jours. \
                        Les données de transactions sont conservées conformément aux obligations légales.
                        """
                    )

                    legalSection(
                        title: "7. Contact",
                        content: "Pour toute question : contact@homelybites.app"
                    )
                }

                Text("Dernière mise à jour : Mars 2026")
                    .font(HBTheme.Font.label(12))
                    .foregroundStyle(HBTheme.Colors.textSecondary)
                    .padding(.top, 8)
            }
            .padding(HBTheme.Spacing.screen)
        }
        .hbBackground()
        .navigationTitle("Confidentialité")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Conditions générales d'utilisation")
                    .font(HBTheme.Font.display(28))
                    .foregroundStyle(HBTheme.Colors.text)

                Group {
                    legalSection(
                        title: "1. Objet",
                        content: """
                        HomelyBites est une plateforme de mise en relation entre des hôtes \
                        proposant des repas faits maison et des clients souhaitant en bénéficier. \
                        HomelyBites agit en tant qu'intermédiaire et n'est pas responsable de la \
                        qualité des repas préparés par les hôtes.
                        """
                    )

                    legalSection(
                        title: "2. Inscription",
                        content: """
                        • L'inscription est gratuite et obligatoire pour utiliser l'application
                        • Vous devez fournir des informations exactes
                        • Vous êtes responsable de la confidentialité de votre compte
                        • Vous devez avoir au moins 18 ans
                        """
                    )

                    legalSection(
                        title: "3. Hôtes - Obligations",
                        content: """
                        Les hôtes s'engagent à :
                        • Respecter les règles d'hygiène alimentaire (HACCP)
                        • Fournir des descriptions exactes de leurs repas
                        • Signaler les allergènes présents
                        • Respecter les délais de service convenus
                        • Disposer des autorisations nécessaires
                        """
                    )

                    legalSection(
                        title: "4. Clients - Obligations",
                        content: """
                        Les clients s'engagent à :
                        • Respecter les hôtes et leurs conditions
                        • Signaler toute allergie alimentaire avant la commande
                        • Effectuer le paiement via l'application
                        • Ne pas contourner la plateforme pour les transactions
                        """
                    )

                    legalSection(
                        title: "5. Paiements",
                        content: """
                        • Les paiements sont traités de manière sécurisée via Stripe
                        • Apple Pay est disponible pour un paiement rapide
                        • Une commission de 15% est prélevée sur chaque transaction
                        • Les remboursements sont gérés au cas par cas
                        """
                    )

                    legalSection(
                        title: "6. Contenu utilisateur",
                        content: """
                        • Vous êtes responsable du contenu que vous publiez
                        • Le contenu inapproprié, offensant ou illégal est interdit
                        • HomelyBites se réserve le droit de supprimer tout contenu inapproprié
                        • Vous pouvez signaler un contenu via le bouton de signalement
                        """
                    )

                    legalSection(
                        title: "7. Responsabilité",
                        content: """
                        HomelyBites ne peut être tenu responsable :
                        • De la qualité des repas préparés par les hôtes
                        • Des problèmes de santé liés à la consommation
                        • Des litiges entre utilisateurs
                        L'application est fournie « en l'état ».
                        """
                    )

                    legalSection(
                        title: "8. Résiliation",
                        content: """
                        Vous pouvez supprimer votre compte à tout moment depuis les réglages. \
                        HomelyBites peut suspendre ou supprimer un compte en cas de violation des CGU.
                        """
                    )
                }

                Text("Dernière mise à jour : Mars 2026")
                    .font(HBTheme.Font.label(12))
                    .foregroundStyle(HBTheme.Colors.textSecondary)
                    .padding(.top, 8)
            }
            .padding(HBTheme.Spacing.screen)
        }
        .hbBackground()
        .navigationTitle("CGU")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared Legal Section Builder
private func legalSection(title: String, content: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(HBTheme.Font.body(18, weight: .semibold))
            .foregroundStyle(HBTheme.Colors.text)
        Text(content)
            .font(HBTheme.Font.body(14))
            .foregroundStyle(HBTheme.Colors.textSecondary)
            .lineSpacing(4)
    }
}

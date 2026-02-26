import SwiftUI

struct MealDetailView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MealDetailViewModel

    init(
        meal: Meal,
        functionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        _viewModel = StateObject(
            wrappedValue: MealDetailViewModel(
                meal: meal,
                functionsService: functionsService
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HBMetrics.Spacing.l) {
                heroSection

                CardContainer {
                    Text(viewModel.meal.description)
                        .font(HBTypography.body(size: 16))
                        .foregroundStyle(HBColors.textSecondary)
                        .lineSpacing(4)
                }

                CardContainer {
                    Text("Informations")
                        .hbTitle()

                    infoRow(icon: "person.circle.fill", title: "Host", value: viewModel.meal.hostName)
                    infoRow(icon: "bag.fill", title: "Service", value: (viewModel.meal.serviceMode ?? .onSite).displayTitle)
                    infoRow(icon: "square.grid.2x2.fill", title: "Disponible", value: "\(viewModel.meal.availablePortions) portions")
                }

                CardContainer {
                    Text("Réservation")
                        .hbTitle()

                    HStack {
                        Text("Portions")
                            .font(HBTypography.body(size: 16, weight: .medium))
                            .foregroundStyle(HBColors.textPrimary)

                        Spacer()

                        HStack(spacing: HBMetrics.Spacing.m) {
                            Button {
                                if viewModel.portions > 1 {
                                    viewModel.portions -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(HBColors.terracotta)
                            }
                            .disabled(viewModel.portions <= 1)

                            Text("\(viewModel.portions)")
                                .font(HBTypography.title(size: 24, weight: .semibold))
                                .foregroundStyle(HBColors.textPrimary)
                                .frame(minWidth: 44)

                            Button {
                                if viewModel.portions < viewModel.meal.availablePortions {
                                    viewModel.portions += 1
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(HBColors.terracotta)
                            }
                            .disabled(viewModel.portions >= viewModel.meal.availablePortions)
                        }
                    }

                    if viewModel.meal.availableServiceModes.count > 1 {
                        VStack(alignment: .leading, spacing: HBMetrics.Spacing.s) {
                            Text("Mode de service")
                                .font(HBTypography.label(size: 13, weight: .semibold))
                                .foregroundStyle(HBColors.textSecondary)

                            Picker("Mode", selection: $viewModel.selectedServiceMode) {
                                ForEach(viewModel.meal.availableServiceModes) { mode in
                                    Text(mode.displayTitle).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    VStack(alignment: .leading, spacing: HBMetrics.Spacing.s) {
                        Text("Note (optionnelle)")
                            .font(HBTypography.label(size: 13, weight: .semibold))
                            .foregroundStyle(HBColors.textSecondary)

                        TextField("Allergies, préférences...", text: $viewModel.note, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .font(HBTypography.body(size: 15))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: HBMetrics.Radius.input, style: .continuous)
                                    .fill(HBColors.warmWhite)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: HBMetrics.Radius.input, style: .continuous)
                                    .stroke(HBColors.border, lineWidth: 1)
                            )
                    }

                    if viewModel.confirmationInProgress {
                        HStack(spacing: HBMetrics.Spacing.s) {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundStyle(HBColors.warning)
                            Text("Confirmation en cours... vérifie l'onglet Commandes.")
                                .font(HBTypography.label(size: 12))
                                .foregroundStyle(HBColors.warning)
                        }
                    }
                }
            }
            .padding(.horizontal, HBMetrics.horizontalPadding)
            .padding(.top, HBMetrics.Spacing.m)
            .padding(.bottom, 220)
        }
        .background(HBColors.cream.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            footerSection
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.checkoutSession != nil },
                set: { if !$0 { viewModel.checkoutSession = nil } }
            )
        ) {
            if let checkoutSession = viewModel.checkoutSession {
                CheckoutView(
                    orderId: checkoutSession.orderId,
                    amountCents: viewModel.totalPriceCents,
                    itemLabel: viewModel.meal.title
                ) {
                    viewModel.paymentDidComplete()
                }
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

    private var heroSection: some View {
        ZStack(alignment: .top) {
            ZStack {
                LinearGradient(
                    colors: [HBColors.charcoal, HBColors.terracottaDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let imageURL = viewModel.meal.imageURL,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "photo")
                                .font(.system(size: 46, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                    .overlay(Color.black.opacity(0.24))
                }
            }

            VStack(alignment: .leading, spacing: HBMetrics.Spacing.m) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Spacer()

                    Badge(
                        label: (viewModel.meal.serviceMode ?? .onSite).displayTitle,
                        kind: .info
                    )
                }

                Spacer()

                VStack(alignment: .leading, spacing: HBMetrics.Spacing.s) {
                    Text(viewModel.meal.title)
                        .font(HBTypography.display(size: 40))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack {
                        Text(viewModel.meal.hostName)
                            .font(HBTypography.body(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.9))

                        Spacer()

                        Text(viewModel.meal.priceCents.asEuro())
                            .font(HBTypography.title(size: 28, weight: .semibold))
                            .foregroundStyle(HBColors.terracottaLight)
                    }
                }
            }
            .padding(HBMetrics.cardPadding)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: HBMetrics.Radius.card, style: .continuous))
        .hbShadow(.strong)
    }

    private var footerSection: some View {
        VStack(spacing: HBMetrics.Spacing.m) {
            HStack {
                Text("Total")
                    .font(HBTypography.body(size: 15, weight: .medium))
                    .foregroundStyle(HBColors.textSecondary)
                Spacer()
                Text(viewModel.totalPriceCents.asEuro())
                    .font(HBTypography.title(size: 30, weight: .semibold))
                    .foregroundStyle(HBColors.terracotta)
            }

            PrimaryButton(
                title: "Réserver & payer par carte",
                icon: "creditcard.fill",
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.isLoading || viewModel.checkoutSession != nil
            ) {
                guard session.appUser?.id != nil else {
                    viewModel.errorMessage = AppError.missingAuth.localizedDescription
                    return
                }
                Task {
                    await viewModel.reserveAndPay()
                }
            }
        }
        .padding(.horizontal, HBMetrics.horizontalPadding)
        .padding(.top, HBMetrics.Spacing.s)
        .padding(.bottom, HBMetrics.Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HBColors.border)
                .frame(height: 1)
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(HBTypography.body(size: 14, weight: .medium))
                .foregroundStyle(HBColors.textPrimary)
            Spacer()
            Text(value)
                .font(HBTypography.body(size: 14))
                .foregroundStyle(HBColors.textSecondary)
        }
    }
}

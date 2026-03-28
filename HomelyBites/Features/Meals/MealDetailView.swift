import SwiftUI

struct MealDetailView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MealDetailViewModel
    @State private var showReportSheet = false

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
            VStack(alignment: .leading, spacing: HBTheme.Spacing.l) {
                heroSection

                CardContainer {
                    Text(viewModel.meal.description)
                        .font(HBTheme.Font.body())
                        .foregroundStyle(HBTheme.Colors.textSecondary)
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
                    Text("Reservation")
                        .hbTitle()

                    HStack {
                        Text("Portions")
                            .font(HBTheme.Font.body(16, weight: .medium))
                            .foregroundStyle(HBTheme.Colors.text)
                        Spacer()
                        HStack(spacing: HBTheme.Spacing.m) {
                            Button {
                                if viewModel.portions > 1 { viewModel.portions -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(HBTheme.Colors.primary)
                            }
                            .disabled(viewModel.portions <= 1)

                            Text("\(viewModel.portions)")
                                .font(HBTheme.Font.title(24))
                                .foregroundStyle(HBTheme.Colors.text)
                                .frame(minWidth: 44)

                            Button {
                                if viewModel.portions < viewModel.meal.availablePortions { viewModel.portions += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(HBTheme.Colors.primary)
                            }
                            .disabled(viewModel.portions >= viewModel.meal.availablePortions)
                        }
                    }

                    if viewModel.meal.availableServiceModes.count > 1 {
                        VStack(alignment: .leading, spacing: HBTheme.Spacing.s) {
                            Text("Mode de service")
                                .font(HBTheme.Font.label(13, weight: .semibold))
                                .foregroundStyle(HBTheme.Colors.textSecondary)
                            Picker("Mode", selection: $viewModel.selectedServiceMode) {
                                ForEach(viewModel.meal.availableServiceModes) { mode in
                                    Text(mode.displayTitle).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    VStack(alignment: .leading, spacing: HBTheme.Spacing.s) {
                        Text("Note (optionnelle)")
                            .font(HBTheme.Font.label(13, weight: .semibold))
                            .foregroundStyle(HBTheme.Colors.textSecondary)
                        TextField("Allergies, preferences...", text: $viewModel.note, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .hbInputStyle()
                    }

                    if viewModel.confirmationInProgress {
                        HStack(spacing: HBTheme.Spacing.s) {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundStyle(HBTheme.Colors.warning)
                            Text("Confirmation en cours... verifie l'onglet Commandes.")
                                .font(HBTheme.Font.label(12))
                                .foregroundStyle(HBTheme.Colors.warning)
                        }
                    }
                }
            }
            .padding(.horizontal, HBTheme.Spacing.screen)
            .padding(.top, HBTheme.Spacing.m)
            .padding(.bottom, 220)
        }
        .hbBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { footerSection }
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
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentType: .meal,
                contentId: viewModel.meal.id
            )
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .top) {
            ZStack {
                LinearGradient(
                    colors: [HBTheme.Colors.text, HBTheme.Colors.primaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let imageURL = viewModel.meal.imageURL,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "photo")
                                .font(.system(size: 46, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                    .overlay(Color.black.opacity(0.24))
                }
            }

            VStack(alignment: .leading, spacing: HBTheme.Spacing.m) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Button { showReportSheet = true } label: {
                        Image(systemName: "flag")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Badge(
                        label: (viewModel.meal.serviceMode ?? .onSite).displayTitle,
                        kind: .info
                    )
                }

                Spacer()

                VStack(alignment: .leading, spacing: HBTheme.Spacing.s) {
                    Text(viewModel.meal.title)
                        .font(HBTheme.Font.display(40))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack {
                        Text(viewModel.meal.hostName)
                            .font(HBTheme.Font.body(15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.9))
                        Spacer()
                        Text(viewModel.meal.priceCents.asEuro())
                            .font(HBTheme.Font.title(28))
                            .foregroundStyle(HBTheme.Colors.primaryLight)
                    }
                }
            }
            .padding(HBTheme.Spacing.m)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: HBTheme.Radius.card, style: .continuous))
        .hbShadow(.strong)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: HBTheme.Spacing.m) {
            HStack {
                Text("Total")
                    .font(HBTheme.Font.body(15, weight: .medium))
                    .foregroundStyle(HBTheme.Colors.textSecondary)
                Spacer()
                Text(viewModel.totalPriceCents.asEuro())
                    .font(HBTheme.Font.title(30))
                    .foregroundStyle(HBTheme.Colors.primary)
            }

            PrimaryButton(
                title: "Reserver & payer par carte",
                icon: "creditcard.fill",
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.isLoading || viewModel.checkoutSession != nil
            ) {
                guard session.appUser?.id != nil else {
                    viewModel.errorMessage = AppError.missingAuth.localizedDescription
                    return
                }
                Task { await viewModel.reserveAndPay() }
            }
        }
        .padding(.horizontal, HBTheme.Spacing.screen)
        .padding(.top, HBTheme.Spacing.s)
        .padding(.bottom, HBTheme.Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(HBTheme.Colors.border).frame(height: 1)
        }
    }

    // MARK: - Helpers

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(HBTheme.Font.body(14, weight: .medium))
                .foregroundStyle(HBTheme.Colors.text)
            Spacer()
            Text(value)
                .font(HBTheme.Font.body(14))
                .foregroundStyle(HBTheme.Colors.textSecondary)
        }
    }
}

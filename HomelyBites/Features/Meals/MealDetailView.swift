import SwiftUI
import PassKit

struct MealDetailView: View {
    @EnvironmentObject private var session: SessionViewModel
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
            VStack(alignment: .leading, spacing: 20) {
                // Hero Image
                if let imageURL = viewModel.meal.imageURL,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius)
                                .fill(AppColors.creamDark)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                                }
                        }
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius))
                }

                // Title & Price
                HStack(alignment: .top) {
                    Text(viewModel.meal.title)
                        .font(.cormorantDisplay(32, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                    Spacer()
                    Text(viewModel.meal.priceCents.asEuro())
                        .font(.dmSans(24, weight: .bold))
                        .foregroundStyle(AppColors.terracotta)
                }

                // Description
                Text(viewModel.meal.description)
                    .font(.bodyLarge)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(4)

                // Host Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Informations")
                        .font(.headlineSmall)
                        .foregroundStyle(AppColors.charcoal)

                    HStack {
                        Label("Host", systemImage: "person.circle.fill")
                            .font(.bodyMedium)
                        Spacer()
                        Text(viewModel.meal.hostName)
                            .font(.dmSans(15, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    HStack {
                        Label("Service", systemImage: "bag.fill")
                            .font(.bodyMedium)
                        Spacer()
                        Text((viewModel.meal.serviceMode ?? .onSite).displayTitle)
                            .font(.dmSans(15, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    HStack {
                        Label("Disponible", systemImage: "leaf.fill")
                            .font(.bodyMedium)
                        Spacer()
                        Text("\(viewModel.meal.availablePortions) portions")
                            .font(.dmSans(15, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(16)
                .appCard()

                // Reservation Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Réservation")
                        .font(.headlineSmall)
                        .foregroundStyle(AppColors.charcoal)

                    // Portions Stepper
                    HStack {
                        Text("Portions")
                            .font(.bodyLarge)
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                if viewModel.portions > 1 {
                                    viewModel.portions -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppColors.terracotta)
                            }
                            .disabled(viewModel.portions <= 1)

                            Text("\(viewModel.portions)")
                                .font(.dmSans(20, weight: .semibold))
                                .frame(minWidth: 40)

                            Button {
                                if viewModel.portions < viewModel.meal.availablePortions {
                                    viewModel.portions += 1
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppColors.terracotta)
                            }
                            .disabled(viewModel.portions >= viewModel.meal.availablePortions)
                        }
                    }

                    // Service Mode Picker
                    if viewModel.meal.availableServiceModes.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mode de service")
                                .font(.bodyMedium)
                            Picker("Mode", selection: $viewModel.selectedServiceMode) {
                                ForEach(viewModel.meal.availableServiceModes) { mode in
                                    Text(mode.displayTitle).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Note Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optionnelle)")
                            .font(.bodyMedium)
                        TextField("Allergies, préférences...", text: $viewModel.note, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .appTextFieldStyle()
                    }

                    // Total Price
                    HStack {
                        Text("Total")
                            .font(.headlineMedium)
                            .foregroundStyle(AppColors.charcoal)
                        Spacer()
                        Text(viewModel.totalPriceCents.asEuro())
                            .font(.cormorantDisplay(28, weight: .semibold))
                            .foregroundStyle(AppColors.terracotta)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .appCard()

                // Confirmation Status
                if viewModel.confirmationInProgress {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 20))
                        Text("Confirmation en cours... vérifie l'onglet Commandes.")
                            .font(.bodyMedium)
                    }
                    .foregroundStyle(AppColors.warning)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.warning.opacity(0.1))
                    )
                }

                // Payment Buttons
                VStack(spacing: 12) {
                    // Apple Pay Button
                    if PKPaymentAuthorizationController.canMakePayments() {
                        ApplePayButton(
                            amount: viewModel.totalPriceCents,
                            onSuccess: { token in
                                Task {
                                    await viewModel.reserveWithApplePay(token: token)
                                }
                            },
                            onError: { error in
                                viewModel.errorMessage = error.localizedDescription
                            }
                        )
                    }

                    // Standard Payment Button
                    Button {
                        guard session.appUser?.id != nil else {
                            viewModel.errorMessage = AppError.missingAuth.localizedDescription
                            return
                        }
                        Task {
                            await viewModel.reserveAndPay()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Réserver & payer par carte")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading))
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.cream)
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
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
}

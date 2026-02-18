import SwiftUI

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
        Form {
            Section("Repas") {
                Text(viewModel.meal.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(viewModel.meal.description)
                    .foregroundStyle(AppColors.textSecondary)
                HStack {
                    Text("Host")
                    Spacer()
                    Text(viewModel.meal.hostName)
                        .foregroundStyle(AppColors.textSecondary)
                }
                HStack {
                    Text("Prix unitaire")
                    Spacer()
                    Text(viewModel.meal.priceCents.asEuro())
                        .foregroundStyle(AppColors.primary)
                }
            }

            Section("Reservation") {
                Stepper("Portions: \(viewModel.portions)", value: $viewModel.portions, in: 1...max(1, viewModel.meal.availablePortions))

                Text("Total: \(viewModel.totalPriceCents.asEuro())")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                TextField("Note (optionnelle)", text: $viewModel.note, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .appTextFieldStyle()
            }

            if viewModel.confirmationInProgress {
                Section {
                    Label("Confirmation en cours... verifie l'onglet Commandes.", systemImage: "clock.badge.checkmark")
                        .foregroundStyle(.orange)
                }
            }

            Section {
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
                        Text("Reserver & payer")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading))
                .disabled(viewModel.isLoading)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Detail")
        .sheet(
            isPresented: Binding(
                get: { viewModel.checkoutSession != nil },
                set: { if !$0 { viewModel.checkoutSession = nil } }
            )
        ) {
            if let checkoutSession = viewModel.checkoutSession {
                CheckoutView(
                    orderId: checkoutSession.orderId,
                    clientSecret: checkoutSession.clientSecret
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

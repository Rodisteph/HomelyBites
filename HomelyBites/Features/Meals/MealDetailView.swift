import SwiftUI

struct MealDetailView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel: MealDetailViewModel

    init(meal: Meal) {
        _viewModel = StateObject(wrappedValue: MealDetailViewModel(meal: meal))
    }

    var body: some View {
        Form {
            Section("Repas") {
                Text(viewModel.meal.title)
                    .font(.title3.weight(.bold))
                Text(viewModel.meal.description)
                HStack {
                    Text("Host")
                    Spacer()
                    Text(viewModel.meal.hostName)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Prix unitaire")
                    Spacer()
                    Text(viewModel.meal.priceCents.asEuro())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Reservation") {
                Stepper("Portions: \(viewModel.portions)", value: $viewModel.portions, in: 1...max(1, viewModel.meal.availablePortions))

                Text("Total: \(viewModel.totalPriceCents.asEuro())")
                    .font(.headline)

                TextField("Note (optionnelle)", text: $viewModel.note, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            if viewModel.confirmationInProgress {
                Section {
                    Label("Confirmation en cours... verifie l'onglet Commandes.", systemImage: "clock.badge.checkmark")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Button {
                    guard let clientId = session.appUser?.id else {
                        viewModel.errorMessage = AppError.missingAuth.localizedDescription
                        return
                    }
                    Task {
                        await viewModel.reserveAndPay(clientId: clientId)
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Reserver & payer")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Detail")
        .sheet(
            isPresented: Binding(
                get: { viewModel.createdOrderId != nil },
                set: { if !$0 { viewModel.createdOrderId = nil } }
            )
        ) {
            if let orderId = viewModel.createdOrderId {
                CheckoutView(orderId: orderId) {
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

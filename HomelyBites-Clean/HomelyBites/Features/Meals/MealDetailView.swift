import SwiftUI

struct MealDetailView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var viewModel: MealDetailViewModel

    init(meal: Meal) {
        _viewModel = State(initialValue: MealDetailViewModel(meal: meal))
    }

    var body: some View {
        Form {
            Section("Repas") {
                Text(viewModel.meal.title).font(.title3.weight(.bold))
                Text(viewModel.meal.description)
                row("Host",          value: viewModel.meal.hostName)
                row("Prix unitaire", value: viewModel.meal.priceCents.asEuro())
            }

            Section("Réservation") {
                Stepper(
                    "Portions : \(viewModel.portions)",
                    value: $viewModel.portions,
                    in: 1...max(1, viewModel.meal.availablePortions)
                )
                Text("Total : \(viewModel.totalPriceCents.asEuro())").font(.headline)
                TextField("Note (optionnelle)", text: $viewModel.note, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            if viewModel.confirmationInProgress {
                Section {
                    Label("Confirmation en cours… vérifie l'onglet Commandes.",
                          systemImage: "clock.badge.checkmark")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Button {
                    guard let clientId = session.appUser?.id else {
                        viewModel.errorMessage = AppError.missingAuth.localizedDescription
                        return
                    }
                    Task { await viewModel.reserveAndPay(clientId: clientId) }
                } label: {
                    if viewModel.isLoading { ProgressView() }
                    else { Text("Réserver & payer") }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Détail")
        .sheet(isPresented: Binding(
            get:  { viewModel.createdOrderId != nil },
            set:  { if !$0 { viewModel.createdOrderId = nil } }
        )) {
            if let orderId = viewModel.createdOrderId {
                CheckoutView(orderId: orderId) { viewModel.paymentDidComplete() }
            }
        }
        .errorAlert(message: $viewModel.errorMessage)
    }

    // Petite ligne clé/valeur réutilisable dans ce Form
    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

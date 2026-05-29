import SwiftUI

struct MealListView: View {
    @State private var viewModel = MealListViewModel()

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.meals.isEmpty {
                ProgressView("Chargement des repas...")
            } else if viewModel.meals.isEmpty {
                ContentUnavailableView(
                    "Aucun repas",
                    systemImage: "fork.knife.circle",
                    description: Text("Les hosts n'ont pas encore publié de repas.")
                )
            } else {
                ForEach(viewModel.meals) { meal in
                    NavigationLink { MealDetailView(meal: meal) } label: {
                        MealRowView(meal: meal)
                    }
                }
            }
        }
        .navigationTitle("Repas")
        .refreshable { await viewModel.loadMeals() }
        .task { if viewModel.meals.isEmpty { await viewModel.loadMeals() } }
        .errorAlert(message: $viewModel.errorMessage)
    }
}

// MARK: - Sous-composant (privé à ce fichier)

private struct MealRowView: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meal.title).font(.headline)
                Spacer()
                Text(meal.priceCents.asEuro()).font(.subheadline.weight(.semibold))
            }
            Text(meal.description)
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            HStack {
                Label(meal.hostName, systemImage: "person")
                Spacer()
                Label("\(meal.availablePortions)", systemImage: "shippingbox")
            }
            .font(.caption).foregroundStyle(.secondary)

            if !meal.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(meal.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.gray.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

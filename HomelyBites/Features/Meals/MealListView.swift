import SwiftUI

struct MealListView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = MealListViewModel()

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.meals.isEmpty {
                ProgressView("Chargement des repas...")
                    .tint(AppColors.primary)
            } else if viewModel.meals.isEmpty {
                ContentUnavailableView(
                    "Aucun repas",
                    systemImage: "fork.knife.circle",
                    description: Text("Les hosts n'ont pas encore publie de repas.")
                )
            } else {
                ForEach(viewModel.meals) { meal in
                    NavigationLink {
                        MealDetailView(
                            meal: meal,
                            functionsService: container.cloudFunctionsService
                        )
                    } label: {
                        MealRowView(meal: meal)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Repas")
        .refreshable {
            await viewModel.loadMeals()
        }
        .task {
            if viewModel.meals.isEmpty {
                await viewModel.loadMeals()
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

private struct MealRowView: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meal.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(meal.priceCents.asEuro())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
            }

            Text(meal.description)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)

            HStack {
                Label(meal.hostName, systemImage: "person")
                Spacer()
                Label("\(meal.availablePortions)", systemImage: "shippingbox")
            }
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)

            if !meal.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(meal.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.primary.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .appCard()
    }
}

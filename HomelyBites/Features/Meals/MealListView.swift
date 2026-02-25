import SwiftUI

struct MealListView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = MealListViewModel()
    @State private var searchText = ""
    @State private var selectedCategory = "Tous"

    var body: some View {
        VStack(spacing: 0) {
            if categories.count > 1 {
                categoryBar
                    .zIndex(1)
            }

            List {
                if viewModel.isLoading && viewModel.meals.isEmpty {
                    ProgressView("Chargement des repas...")
                        .tint(AppColors.terracotta)
                } else if viewModel.meals.isEmpty {
                    ContentUnavailableView(
                        "Aucun repas",
                        systemImage: "fork.knife.circle",
                        description: Text("Les hosts n'ont pas encore publié de repas.")
                    )
                } else if filteredMeals.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "magnifyingglass",
                        description: Text("Ajuste ta recherche ou la catégorie.")
                    )
                } else {
                    Section {
                        Text("Repas près de vous")
                            .font(.cormorantDisplay(24, weight: .semibold))
                            .foregroundStyle(AppColors.charcoal)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(nearbyMeals) { meal in
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

                    Section {
                        Text("Tous les repas")
                            .font(.cormorantDisplay(24, weight: .semibold))
                            .foregroundStyle(AppColors.charcoal)
                            .padding(.vertical, 8)
                            .padding(.top, 16)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(filteredMeals) { meal in
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
        }
        .background(AppColors.cream)
        .navigationTitle("Repas")
        .searchable(text: $searchText, prompt: "Rechercher un plat, un host...")
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

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.dmSans(14, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category ?
                                AppColors.terracotta :
                                AppColors.surface,
                                in: Capsule()
                            )
                            .foregroundStyle(
                                selectedCategory == category ?
                                Color.white :
                                AppColors.textSecondary
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.cream)
    }

    private var categories: [String] {
        let dynamic = Set(viewModel.meals.flatMap(\.tags))
        return ["Tous"] + dynamic.sorted()
    }

    private var filteredMeals: [Meal] {
        viewModel.meals.filter { meal in
            let byCategory = selectedCategory == "Tous" || meal.tags.contains(selectedCategory)
            guard byCategory else { return false }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return true }

            return meal.title.lowercased().contains(query)
                || meal.description.lowercased().contains(query)
                || meal.hostName.lowercased().contains(query)
                || meal.tags.contains(where: { $0.lowercased().contains(query) })
        }
    }

    private var nearbyMeals: [Meal] {
        Array(filteredMeals.prefix(3))
    }
}

private struct MealRowView: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageURL = meal.imageURL,
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
                                    .font(.system(size: 32))
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                            }
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(meal.title)
                        .font(.cormorantDisplay(22, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                        .lineLimit(2)
                    Spacer()
                    Text(meal.priceCents.asEuro())
                        .font(.dmSans(18, weight: .bold))
                        .foregroundStyle(AppColors.terracotta)
                }

                Text(meal.description)
                    .font(.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(meal.hostName, systemImage: "person.circle.fill")
                    Spacer()
                    Label("\(meal.availablePortions) portions", systemImage: "leaf.fill")
                }
                .font(.labelMedium)
                .foregroundStyle(AppColors.textSecondary)

                if !meal.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(meal.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.labelSmall)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        AppColors.terracottaLight.opacity(0.3),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(AppColors.terracottaDark)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .appCard()
    }
}

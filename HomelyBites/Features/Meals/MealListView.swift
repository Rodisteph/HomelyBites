import SwiftUI

struct MealListView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = MealListViewModel()
    @State private var searchText = ""
    @State private var selectedCategory = "Tous"
    @State private var showMap = false

    var body: some View {
        VStack(spacing: 0) {
            if categories.count > 1 {
                categoryBar
                    .zIndex(1)
            }

            if showMap {
                MapView()
            } else {
                mealList
            }
        }
        .hbBackground()
        .navigationTitle("Repas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMap.toggle()
                    }
                } label: {
                    Image(systemName: showMap ? "list.bullet" : "map")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HBTheme.Colors.primary)
                }
            }
        }
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
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }

    private var mealList: some View {
        ScrollView {
            LazyVStack(spacing: HBTheme.Spacing.m) {
                if viewModel.isLoading && viewModel.meals.isEmpty {
                    ProgressView("Chargement...")
                        .tint(HBTheme.Colors.primary)
                        .padding(.top, 60)
                } else if filteredMeals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.meals.isEmpty ? "fork.knife.circle" : "magnifyingglass")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(HBTheme.Colors.textSecondary.opacity(0.5))
                        Text(viewModel.meals.isEmpty ? "Aucun repas disponible" : "Aucun resultat")
                            .font(HBTheme.Font.title(22))
                            .foregroundStyle(HBTheme.Colors.text)
                        Text(viewModel.meals.isEmpty ? "Les repas apparaitront ici." : "Ajuste ta recherche ou la categorie.")
                            .font(HBTheme.Font.body(14))
                            .foregroundStyle(HBTheme.Colors.textSecondary)
                    }
                    .padding(.top, 80)
                } else {
                    ForEach(filteredMeals) { meal in
                        NavigationLink {
                            MealDetailView(
                                meal: meal,
                                functionsService: container.cloudFunctionsService
                            )
                        } label: {
                            MealRowView(meal: meal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, HBTheme.Spacing.screen)
            .padding(.vertical, HBTheme.Spacing.m)
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .hbChipStyle(selected: selectedCategory == category)
                    }
                }
            }
            .padding(.horizontal, HBTheme.Spacing.m)
            .padding(.vertical, HBTheme.Spacing.s)
        }
        .background(HBTheme.Colors.background)
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
}

// MARK: - Meal Row

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
                        Rectangle()
                            .fill(HBTheme.Colors.skeleton)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 28))
                                    .foregroundStyle(HBTheme.Colors.textSecondary.opacity(0.4))
                            }
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: HBTheme.Radius.card))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(meal.title)
                        .font(HBTheme.Font.cardTitle)
                        .foregroundStyle(HBTheme.Colors.text)
                        .lineLimit(2)
                    Spacer()
                    Text(meal.priceCents.asEuro())
                        .font(HBTheme.Font.price)
                        .foregroundStyle(HBTheme.Colors.primary)
                }

                Text(meal.description)
                    .font(HBTheme.Font.body(14))
                    .foregroundStyle(HBTheme.Colors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(meal.hostName, systemImage: "person.circle.fill")
                    Spacer()
                    Label("\(meal.availablePortions) portions", systemImage: "leaf.fill")
                }
                .font(HBTheme.Font.caption)
                .foregroundStyle(HBTheme.Colors.textSecondary)

                if !meal.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(meal.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(HBTheme.Font.label(11))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        HBTheme.Colors.primaryLight.opacity(0.2),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(HBTheme.Colors.primaryDark)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .hbCard()
    }
}

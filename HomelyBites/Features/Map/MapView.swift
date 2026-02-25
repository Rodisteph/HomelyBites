import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

struct MapView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationService = MapLocationService()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPin: MealMapPin?
    @State private var radiusKm: Double = 10
    @State private var isBackfillingLocations = false

    var body: some View {
        Group {
            if viewModel.isLoading && filteredPins.isEmpty {
                ProgressView("Chargement de la carte...")
                    .tint(AppColors.primary)
            } else if filteredPins.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "Aucun repas disponible",
                        systemImage: "map",
                        description: Text("Les repas apparaîtront sur la carte dès qu'ils seront publiés avec une localisation.")
                    )

                    #if DEBUG
                    VStack(spacing: 8) {
                        Text("Debug: \(viewModel.pins.count) repas trouvés sans localisation")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Button {
                            Task { await backfillLocationsDevOnly() }
                        } label: {
                            if isBackfillingLocations {
                                HStack {
                                    ProgressView()
                                    Text("Backfill en cours...")
                                }
                            } else {
                                Text("Backfill localisation (dev only)")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: isBackfillingLocations))
                        .disabled(isBackfillingLocations)
                    }
                    .padding(.horizontal, 20)
                    #endif
                }
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    controls

                    Map(position: $cameraPosition, selection: $selectedPin) {
                        ForEach(filteredPins) { pin in
                            Marker(pin.title, coordinate: pin.coordinate)
                                .tag(pin)
                        }
                    }
                    .mapStyle(.standard)

                    if let selectedPin {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(selectedPin.title)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Text(selectedPin.priceCents.asEuro())
                                    .foregroundStyle(AppColors.primary)
                            }

                            Text(selectedPin.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            NavigationLink {
                                MealDetailView(
                                    meal: selectedPin.meal,
                                    functionsService: container.cloudFunctionsService
                                )
                            } label: {
                                Text("Voir details")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle(isLoading: false))
                        }
                        .padding(12)
                        .background(AppColors.surface)
                    }
                }
            }
        }
        .navigationTitle("Map")
        .task {
            await loadMap()
        }
        .refreshable {
            await loadMap()
        }
        .onChange(of: locationService.centerCoordinateToken) { _, _ in
            recenterMap()
        }
        .onChange(of: radiusKm) { _, _ in
            recenterMap()
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

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Rayon", selection: $radiusKm) {
                Text("5 km").tag(5.0)
                Text("10 km").tag(10.0)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: locationService.isUsingFallbackCenter ? "location.slash" : "location.fill")
                    .foregroundStyle(locationService.isUsingFallbackCenter ? AppColors.warning : AppColors.success)
                Text(locationService.centerLabel)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("\(filteredPins.count) repas")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.surface)
    }

    private var filteredPins: [MealMapPin] {
        let center = locationService.centerCoordinate
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let maxDistance = radiusKm * 1000

        let nearby = viewModel.pins.filter { pin in
            let mealLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            return mealLocation.distance(from: centerLocation) <= maxDistance
        }

        if !nearby.isEmpty {
            return nearby
        }

        // Fallback UX: if no pin in radius, still show all pins so map is never empty.
        return viewModel.pins
    }

    private func loadMap() async {
        locationService.requestWhenInUseLocation()
        await viewModel.loadPins()
        recenterMap()
    }

    private func backfillLocationsDevOnly() async {
        guard !isBackfillingLocations else { return }
        isBackfillingLocations = true
        defer { isBackfillingLocations = false }

        do {
            let result = try await container.cloudFunctionsService.backfillMealLocations(
                onlyMine: true,
                dryRun: false
            )
            #if DEBUG
            NSLog("%@", "[Map][backfillMealLocations] processed=\(result.processedCount) updated=\(result.updatedCount)")
            #endif
            await viewModel.loadPins()
            recenterMap()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func recenterMap() {
        guard !filteredPins.isEmpty else { return }

        let center = locationService.centerCoordinate
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
        )
        cameraPosition = .region(region)
    }
}

private struct MealMapPin: Identifiable, Hashable {
    let id: String
    let meal: Meal
    let title: String
    let subtitle: String
    let priceCents: Int
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func == (lhs: MealMapPin, rhs: MealMapPin) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
private final class MapViewModel: ObservableObject {
    @Published var pins: [MealMapPin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private lazy var db = Firestore.firestore()

    func loadPins() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("meals").getDocumentsAsync()
            let parsed: [MealMapPin] = snapshot.documents.compactMap { document in
                let data = document.data()
                guard let coordinate = Self.coordinate(from: data),
                      var meal = try? document.data(as: Meal.self) else {
                    return nil
                }

                if meal.id.isEmpty {
                    meal.id = document.documentID
                }

                let locationName = (data["locationName"] as? String)
                    ?? (data["addressApprox"] as? String)
                    ?? (data["city"] as? String)
                    ?? "Location non precisee"

                return MealMapPin(
                    id: document.documentID,
                    meal: meal,
                    title: meal.title,
                    subtitle: "\(locationName) • Host: \(meal.hostName)",
                    priceCents: meal.priceCents,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
            pins = parsed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func coordinate(from data: [String: Any]) -> CLLocationCoordinate2D? {
        if let location = data["location"] as? GeoPoint {
            return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        }

        if let geoPoint = data["geoPoint"] as? GeoPoint {
            return CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
        }

        if let lat = number(from: data["latitude"]),
           let lng = number(from: data["longitude"]) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        if let coordinates = data["coordinates"] as? [String: Any],
           let lat = number(from: coordinates["lat"] ?? coordinates["latitude"]),
           let lng = number(from: coordinates["lng"] ?? coordinates["longitude"]) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        return nil
    }

    private static func number(from value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}

@MainActor
private final class MapLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var centerCoordinate: CLLocationCoordinate2D
    @Published var isUsingFallbackCenter = true

    private let fallbackCoordinate = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
    private let locationManager = CLLocationManager()

    override init() {
        centerCoordinate = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var centerLabel: String {
        isUsingFallbackCenter ? "Centre: Amsterdam (fallback)" : "Centre: position actuelle"
    }

    var centerCoordinateToken: String {
        "\(centerCoordinate.latitude),\(centerCoordinate.longitude)"
    }

    func requestWhenInUseLocation() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .restricted, .denied:
            useFallbackCenter()
        @unknown default:
            useFallbackCenter()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.requestWhenInUseLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { @MainActor in
                self.useFallbackCenter()
            }
            return
        }
        Task { @MainActor in
            self.centerCoordinate = location.coordinate
            self.isUsingFallbackCenter = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        NSLog("%@", "[MapLocation] didFailWithError: \(error.localizedDescription)")
        #endif
        Task { @MainActor in
            self.useFallbackCenter()
        }
    }

    private func useFallbackCenter() {
        centerCoordinate = fallbackCoordinate
        isUsingFallbackCenter = true
    }
}

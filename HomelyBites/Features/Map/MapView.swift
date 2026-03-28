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

    var body: some View {
        Group {
            if viewModel.isLoading && filteredPins.isEmpty {
                ProgressView("Chargement de la carte...")
                    .tint(HBTheme.Colors.primary)
            } else if filteredPins.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(HBTheme.Colors.textSecondary.opacity(0.5))
                    Text("Aucun repas disponible")
                        .font(HBTheme.Font.title(22))
                        .foregroundStyle(HBTheme.Colors.text)
                    Text("Les repas apparaitront sur la carte des qu'ils seront publies.")
                        .font(HBTheme.Font.body(14))
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, HBTheme.Spacing.screen)
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
                        selectedPinCard(pin: selectedPin)
                    }
                }
            }
        }
        .task { await loadMap() }
        .refreshable { await loadMap() }
        .onChange(of: locationService.centerCoordinateToken) { _, _ in recenterMap() }
        .onChange(of: radiusKm) { _, _ in recenterMap() }
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

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Rayon", selection: $radiusKm) {
                Text("5 km").tag(5.0)
                Text("10 km").tag(10.0)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: locationService.isUsingFallbackCenter ? "location.slash" : "location.fill")
                    .foregroundStyle(locationService.isUsingFallbackCenter ? HBTheme.Colors.warning : HBTheme.Colors.success)
                Text(locationService.centerLabel)
                    .font(HBTheme.Font.caption)
                    .foregroundStyle(HBTheme.Colors.textSecondary)
                Spacer()
                Text("\(filteredPins.count) repas")
                    .font(HBTheme.Font.caption)
                    .foregroundStyle(HBTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(HBTheme.Colors.surface)
    }

    // MARK: - Selected Pin

    private func selectedPinCard(pin: MealMapPin) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pin.title)
                    .font(HBTheme.Font.cardTitle)
                    .foregroundStyle(HBTheme.Colors.text)
                Spacer()
                Text(pin.priceCents.asEuro())
                    .font(HBTheme.Font.price)
                    .foregroundStyle(HBTheme.Colors.primary)
            }
            Text(pin.subtitle)
                .font(HBTheme.Font.caption)
                .foregroundStyle(HBTheme.Colors.textSecondary)

            NavigationLink {
                MealDetailView(
                    meal: pin.meal,
                    functionsService: container.cloudFunctionsService
                )
            } label: {
                Text("Voir les details")
                    .font(HBTheme.Font.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: HBTheme.Radius.button, style: .continuous)
                            .fill(HBTheme.Colors.primary)
                    )
            }
        }
        .padding(12)
        .background(HBTheme.Colors.surface)
    }

    // MARK: - Data

    private var filteredPins: [MealMapPin] {
        let center = locationService.centerCoordinate
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let maxDistance = radiusKm * 1000
        let nearby = viewModel.pins.filter { pin in
            let loc = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            return loc.distance(from: centerLocation) <= maxDistance
        }
        return nearby.isEmpty ? viewModel.pins : nearby
    }

    private func loadMap() async {
        locationService.requestWhenInUseLocation()
        await viewModel.loadPins()
        recenterMap()
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

// MARK: - Map Pin

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

    static func == (lhs: MealMapPin, rhs: MealMapPin) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Map ViewModel

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
                      var meal = try? document.data(as: Meal.self) else { return nil }
                if meal.id.isEmpty { meal.id = document.documentID }
                let locationName = (data["locationName"] as? String)
                    ?? (data["addressApprox"] as? String)
                    ?? (data["city"] as? String)
                    ?? "Localisation inconnue"
                return MealMapPin(
                    id: document.documentID,
                    meal: meal,
                    title: meal.title,
                    subtitle: "\(locationName) · \(meal.hostName)",
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
        if let coords = data["coordinates"] as? [String: Any],
           let lat = number(from: coords["lat"] ?? coords["latitude"]),
           let lng = number(from: coords["lng"] ?? coords["longitude"]) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return nil
    }

    private static func number(from value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
}

// MARK: - Location Service

@MainActor
private final class MapLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var centerCoordinate: CLLocationCoordinate2D
    @Published var isUsingFallbackCenter = true

    private let fallback = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
    private let locationManager = CLLocationManager()

    override init() {
        centerCoordinate = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var centerLabel: String {
        isUsingFallbackCenter ? "Centre : Amsterdam (fallback)" : "Centre : position actuelle"
    }

    var centerCoordinateToken: String {
        "\(centerCoordinate.latitude),\(centerCoordinate.longitude)"
    }

    func requestWhenInUseLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: locationManager.requestLocation()
        default: useFallback()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.requestWhenInUseLocation() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { @MainActor in self.useFallback() }
            return
        }
        Task { @MainActor in
            self.centerCoordinate = location.coordinate
            self.isUsingFallbackCenter = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.useFallback() }
    }

    private func useFallback() {
        centerCoordinate = fallback
        isUsingFallbackCenter = true
    }
}

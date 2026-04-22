import SwiftUI
import MapKit
import CoreLocation

struct VeterinaryMapView: View {
    @State private var locationManager = LocationManager.shared
    @State private var veterinaries: [MKMapItem] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                PawPrintBackground()

                if locationManager.authorizationStatus == .denied ||
                   locationManager.authorizationStatus == .restricted {
                    permissionDeniedView
                } else {
                    mapContent
                }
            }
            .navigationTitle("Veterinarias Cercanas")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            locationManager.requestPermissionAndLocation()
        }
        .onChange(of: locationManager.userLocation) { _, location in
            if let location {
                searchNearbyVets(near: location)
            }
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                // User location
                if let userLoc = locationManager.userLocation {
                    Annotation("Tú", coordinate: userLoc.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary)
                                .frame(width: 16, height: 16)
                            Circle()
                                .fill(.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                // Veterinary markers
                ForEach(veterinaries, id: \.self) { item in
                    Marker(item.name ?? "Veterinaria",
                           systemImage: "cross.fill",
                           coordinate: item.placemark.coordinate)
                    .tint(Color.appPrimary)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 300)
            .overlay(alignment: .center) {
                if isSearching {
                    VStack(spacing: 8) {
                        PawLoader()
                        Text("Buscando veterinarias...")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            // Vet list
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let error = searchError {
                        EmptyStateView(
                            icon: "cross.circle",
                            title: "Sin resultados",
                            subtitle: error
                        )
                        .padding(.top, 24)
                    } else if !isSearching && veterinaries.isEmpty && locationManager.userLocation != nil {
                        EmptyStateView(
                            icon: "stethoscope",
                            title: "Sin veterinarias cercanas",
                            subtitle: "No se encontraron clínicas en un radio de 5 km"
                        )
                        .padding(.top, 24)
                    } else if !isSearching && locationManager.userLocation == nil {
                        EmptyStateView(
                            icon: "location.slash",
                            title: "Esperando ubicación",
                            subtitle: "Obteniendo tu posición..."
                        )
                        .padding(.top, 24)
                    } else {
                        ForEach(veterinaries, id: \.self) { item in
                            VetCard(mapItem: item, userLocation: locationManager.userLocation)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                icon: "location.slash.fill",
                title: "Ubicación desactivada",
                subtitle: "Activa la ubicación para AnimalMbs en Ajustes del dispositivo",
                actionTitle: "Abrir Ajustes"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    // MARK: - Search

    private func searchNearbyVets(near location: CLLocation) {
        guard !isSearching else { return }
        isSearching = true
        searchError = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "veterinaria clínica veterinaria"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                let sorted = response.mapItems.prefix(20).sorted { a, b in
                    let la = CLLocation(latitude: a.placemark.coordinate.latitude,
                                       longitude: a.placemark.coordinate.longitude)
                    let lb = CLLocation(latitude: b.placemark.coordinate.latitude,
                                       longitude: b.placemark.coordinate.longitude)
                    return la.distance(from: location) < lb.distance(from: location)
                }
                await MainActor.run {
                    veterinaries = Array(sorted)
                    cameraPosition = .region(request.region)
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchError = "No se encontraron veterinarias cercanas. Intenta ampliar la búsqueda."
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Vet Card

struct VetCard: View {
    let mapItem: MKMapItem
    let userLocation: CLLocation?
    @State private var showingMapPicker = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "cross.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.appPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(mapItem.name ?? "Veterinaria")
                    .font(.appHeadline)
                    .lineLimit(1)

                if let address = mapItem.placemark.title {
                    Text(address)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let distance = distanceText {
                    Text(distance)
                        .font(.appCaption)
                        .foregroundStyle(Color.appBlue)
                        .fontWeight(.semibold)
                }

                if let phone = mapItem.phoneNumber {
                    Link(phone, destination: URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })")!)
                        .font(.appCaption)
                        .foregroundStyle(Color.appPrimary)
                }
            }

            Spacer()

            Button {
                showingMapPicker = true
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.appPrimary)
            }
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .confirmationDialog(
            "Cómo llegar a \(mapItem.name ?? "Veterinaria")",
            isPresented: $showingMapPicker,
            titleVisibility: .visible
        ) {
            Button("Apple Maps") {
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            }
            if let url = googleMapsURL { Button("Google Maps") { UIApplication.shared.open(url) } }
            if let url = wazeURL { Button("Waze") { UIApplication.shared.open(url) } }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }

    private var googleMapsURL: URL? {
        URL(string: "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving")
            ?? URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)")
    }

    private var wazeURL: URL? {
        URL(string: "waze://?ll=\(coordinate.latitude),\(coordinate.longitude)&navigate=yes")
            ?? URL(string: "https://waze.com/ul?ll=\(coordinate.latitude),\(coordinate.longitude)&navigate=yes")
    }

    private var distanceText: String? {
        guard let userLocation else { return nil }
        let vetLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let meters = vetLocation.distance(from: userLocation)
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
}

#Preview {
    VeterinaryMapView()
        .environment(LocationManager.shared)
}

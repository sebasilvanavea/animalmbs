import SwiftUI

@main
struct AnimalMbsApp: App {
    @State private var authManager = AuthManager()
    @State private var petStore = PetStore()
    @State private var locationManager = LocationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(petStore)
                .environment(locationManager)
        }
    }
}

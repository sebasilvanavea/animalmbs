import SwiftUI
import PhotosUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(PetStore.self) private var petStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        } else if !authManager.isAuthenticated {
            LoginView()
                .environment(authManager)
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            PetListView()
                .tabItem {
                    Label("Mascotas", systemImage: selectedTab == 0 ? "pawprint.fill" : "pawprint")
                }
                .tag(0)

            RemindersView()
                .tabItem {
                    Label("Alertas", systemImage: selectedTab == 1 ? "bell.badge.fill" : "bell")
                }
                .tag(1)
                .badge(pendingCount)

            VeterinaryMapView()
                .tabItem {
                    Label("Mapa", systemImage: selectedTab == 2 ? "map.fill" : "map")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                }
                .tag(3)
        }
        .tint(.appPrimary)
        .onAppear {
            NotificationManager.shared.requestPermission()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, authManager.isAuthenticated else { return }
            Task {
                await petStore.loadPets()
            }
        }
    }

    private var pendingCount: Int {
        var count = 0
        for pet in petStore.pets {
            count += pet.vaccines.filter { $0.isOverdue }.count
            count += pet.antiparasitics.filter { $0.isOverdue }.count
        }
        return count
    }
}

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(PetStore.self) private var petStore
    @State private var showingLogoutConfirmation = false
    @State private var userPhotoData: Data? = nil
    @State private var selectedUserPhoto: PhotosPickerItem? = nil
    @State private var isUserPhotoLoading = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedUserPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = userPhotoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.appPrimary.opacity(0.4), lineWidth: 2))
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient.appHeader)
                                            .frame(width: 60, height: 60)
                                        Image(systemName: "pawprint.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                    }
                                }
                                if isUserPhotoLoading {
                                    Circle()
                                        .fill(.black.opacity(0.18))
                                        .frame(width: 60, height: 60)
                                    ProgressView()
                                        .tint(.white)
                                }
                                ZStack {
                                    Circle()
                                        .fill(Color.appPrimary)
                                        .frame(width: 20, height: 20)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                }
                                .offset(x: 2, y: 2)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("AnimalMbs")
                                .font(.appHeadline)
                            Text("\(petStore.pets.count) mascota\(petStore.pets.count == 1 ? "" : "s") registrada\(petStore.pets.count == 1 ? "" : "s")")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedUserPhoto) { _, newItem in
                    Task {
                        guard let userId = authManager.currentUserId,
                              let data = try? await newItem?.loadTransferable(type: Data.self) else { return }

                        do {
                            await MainActor.run {
                                isUserPhotoLoading = true
                            }
                            let photoURL = try await SupabaseClient.shared.uploadUserPhoto(data, userId: userId)
                            _ = try await SupabaseClient.shared.updateUserAvatar(url: photoURL)
                            await MainActor.run {
                                userPhotoData = data
                                authManager.setAvatarURL(photoURL)
                                PhotoStorage.shared.saveUser(data, userId: userId)
                                isUserPhotoLoading = false
                            }
                        } catch {
                            await MainActor.run {
                                petStore.errorMessage = error.localizedDescription
                                isUserPhotoLoading = false
                            }
                        }
                    }
                }
                .onAppear {
                    Task {
                        await loadUserPhoto()
                    }
                }

                Section("Cuenta") {
                    if let email = authManager.currentEmail {
                        Label {
                            Text(email)
                                .font(.appBody)
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Color.appBlue)
                        }
                    }

                    Label {
                        Text("Tus datos se sincronizan entre la app y la web")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(Color.appPrimary)
                    }
                }

                Section("Notificaciones") {
                    Label {
                        Text("Las notificaciones te avisan 3 días antes y el día de cada vacuna o antiparasitario")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Color.appSecondary)
                    }
                }

                Section("Información") {
                    HStack {
                        Label("Versión", systemImage: "info.circle")
                            .font(.appBody)
                        Spacer()
                        Text("2.0.0")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Web", systemImage: "globe")
                            .font(.appBody)
                        Spacer()
                        Text("animalm.netlify.app")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Hecho con", systemImage: "heart.fill")
                            .font(.appBody)
                        Spacer()
                        Text("🐾 para tu mascota")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.appBody)
                    }
                }
            }
            .navigationTitle("Ajustes")
            .confirmationDialog("¿Cerrar sesión?", isPresented: $showingLogoutConfirmation, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Podrás volver a iniciar sesión con tu correo y contraseña")
            }
        }
    }

    @MainActor
    private func setCachedUserPhoto(_ data: Data, userId: UUID) {
        userPhotoData = data
        PhotoStorage.shared.saveUser(data, userId: userId)
    }

    private func loadUserPhoto() async {
        guard let userId = authManager.currentUserId else {
            await MainActor.run {
                userPhotoData = nil
                isUserPhotoLoading = false
            }
            return
        }

        await MainActor.run {
            isUserPhotoLoading = true
        }

        if let avatarURL = authManager.currentAvatarURL,
           let url = URL(string: avatarURL),
           let (data, response) = try? await URLSession.shared.data(from: url),
           let httpResponse = response as? HTTPURLResponse,
           (200...299).contains(httpResponse.statusCode) {
            await MainActor.run {
                setCachedUserPhoto(data, userId: userId)
                isUserPhotoLoading = false
            }
            return
        }

        let cachedData = PhotoStorage.shared.loadUser(userId: userId)
        await MainActor.run {
            userPhotoData = cachedData
            isUserPhotoLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
        .environment(PetStore())
}

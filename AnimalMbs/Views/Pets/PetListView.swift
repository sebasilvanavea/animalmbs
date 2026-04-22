import SwiftUI

struct PetListView: View {
    @Environment(PetStore.self) private var petStore
    @State private var showingAddPet = false
    @State private var searchText = ""

    var filteredPets: [Pet] {
        if searchText.isEmpty { return petStore.pets }
        return petStore.pets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if petStore.pets.isEmpty && !petStore.isLoading {
                    EmptyStateView(
                        icon: "pawprint.fill",
                        title: "¡Agrega tu primera mascota!",
                        subtitle: "Registra a tu compañero peludo para llevar su hoja clínica completa",
                        actionTitle: "Agregar mascota",
                        action: { showingAddPet = true }
                    )
                    .background {
                        PawPrintBackground(opacity: 0.06, count: 15)
                    }
                } else if petStore.isLoading && petStore.pets.isEmpty {
                    VStack(spacing: 16) {
                        PawLoader()
                        Text("Cargando mascotas...")
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPets) { pet in
                                NavigationLink(destination: PetDetailView(petId: pet.id, initialPet: pet)) {
                                    PetCardView(pet: pet)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await petStore.deletePet(pet.id)
                                        }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .searchable(text: $searchText, prompt: "Buscar mascota...")
                    .background {
                        PawPrintBackground(opacity: 0.03, count: 8)
                    }
                }
            }
            .navigationTitle("Mis Mascotas 🐾")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.appPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddEditPetView()
            }
            .refreshable {
                await petStore.loadPets()
            }
            .task {
                await petStore.loadPets()
            }
        }
    }
}

// MARK: - Pet Card
struct PetCardView: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 14) {
            PetAvatar(pet: pet, size: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(pet.name)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(Color.appTextPrimary)

                HStack(spacing: 6) {
                    InfoChip(icon: pet.species.icon, text: pet.species.rawValue, color: pet.species.themeColor)
                    if !pet.breed.isEmpty {
                        Text(pet.breed)
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                HStack(spacing: 8) {
                    if pet.birthDate != nil {
                        Label(pet.age, systemImage: "calendar")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    if pet.weight > 0 {
                        Label(String(format: "%.1f kg", pet.weight), systemImage: "scalemass")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let nextVaccine = pet.nextVaccine {
                    StatusBadge(
                        text: nextVaccine.isOverdue ? "Vencida" : "Próxima",
                        color: nextVaccine.isOverdue ? .appDanger : .appWarning,
                        icon: "syringe.fill"
                    )
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTextTertiary)
            }
        }
        .padding(14)
        .cardStyle()
    }
}

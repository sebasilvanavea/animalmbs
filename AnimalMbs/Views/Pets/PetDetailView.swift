import SwiftUI

struct PetDetailView: View {
    @Environment(PetStore.self) private var petStore
    let petId: UUID
    let initialPet: Pet
    @State private var showingEditPet = false
    @State private var showingAddVaccine = false
    @State private var showingAddAntiparasitic = false
    @State private var showingAddMedicalRecord = false
    @State private var showingClinicalRecord = false
    @State private var showingQRCode = false
    @State private var detailsLoaded = false

    /// Always non-optional: uses store for latest data, falls back to initialPet.
    private var pet: Pet { petStore.pet(id: petId) ?? initialPet }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero header
                heroSection

                // Quick actions
                quickActionsSection

                // Info chips
                if !pet.microchipNumber.isEmpty || pet.sex != .unknown || !pet.color.isEmpty {
                    infoSection
                }

                // Vacunas
                vaccinesCard

                // Antiparasitarios
                antiparasiticsCard

                // Historial médico
                medicalCard

                // Peso
                weightCard
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.appBackground)
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditPet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(pet.species.themeColor)
                }
            }
        }
        .sheet(isPresented: $showingEditPet) {
            AddEditPetView(pet: pet)
        }
        .sheet(isPresented: $showingAddVaccine) {
            AddVaccineView(petId: pet.id)
        }
        .sheet(isPresented: $showingAddAntiparasitic) {
            AddAntiparasiticView(petId: pet.id)
        }
        .sheet(isPresented: $showingAddMedicalRecord) {
            AddMedicalRecordView(petId: pet.id)
        }
        .sheet(isPresented: $showingClinicalRecord) { ClinicalRecordView(pet: pet) }
        .sheet(isPresented: $showingQRCode) { QRCodeView(pet: pet) }
        .task {
            if !detailsLoaded {
                await petStore.loadPetDetails(petId)
                detailsLoaded = true
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 12) {
            PetAvatar(pet: pet, size: 100)

            Text(pet.name)
                .font(.appTitle)

            HStack(spacing: 8) {
                InfoChip(icon: pet.species.icon, text: pet.species.rawValue, color: pet.species.themeColor)
                if !pet.breed.isEmpty {
                    InfoChip(icon: "tag", text: pet.breed, color: .appSecondary)
                }
            }

            HStack(spacing: 12) {
                if pet.birthDate != nil {
                    Label(pet.age, systemImage: "birthday.cake")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                if pet.weight > 0 {
                    Label(String(format: "%.1f kg", pet.weight), systemImage: "scalemass.fill")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Label(pet.sex.rawValue, systemImage: pet.sex == .male ? "circle.fill" : pet.sex == .female ? "circle.fill" : "questionmark.circle")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBackground)
                .overlay {
                    PawPrintBackground(opacity: 0.05, count: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
        }
        .shadow(color: pet.species.themeColor.opacity(0.1), radius: 10, y: 4)
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            quickActionButton(icon: "doc.text.fill", title: "Ficha", color: .appPrimary) {
                showingClinicalRecord = true
            }
            quickActionButton(icon: "qrcode", title: "QR", color: .appTertiary) {
                showingQRCode = true
            }
            quickActionButton(icon: "chart.line.uptrend.xyaxis", title: "Peso", color: .appBlue) {
                // Navigate to weight - handled via NavigationLink below
            }
            quickActionButton(icon: "square.and.arrow.up", title: "Compartir", color: .appSecondary) {
                showingClinicalRecord = true
            }
        }
    }

    private func quickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !pet.color.isEmpty {
                LabeledContent {
                    Text(pet.color).font(.appBody)
                } label: {
                    Label("Color", systemImage: "paintpalette.fill").font(.appBody)
                }
            }
            if !pet.microchipNumber.isEmpty {
                LabeledContent {
                    Text(pet.microchipNumber).font(.appBody)
                } label: {
                    Label("Microchip", systemImage: "barcode").font(.appBody)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    // MARK: - Vaccines Card
    private var vaccinesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Vacunas", icon: "syringe.fill", color: .appPrimary, addAction: { showingAddVaccine = true })

            if pet.vaccines.isEmpty {
                emptyRowView("Sin vacunas registradas", icon: "syringe")
            } else {
                ForEach(pet.vaccines.sorted(by: { $0.date > $1.date }).prefix(3), id: \.id) { vaccine in
                    VaccineRowView(vaccine: vaccine)
                    if vaccine.id != pet.vaccines.sorted(by: { $0.date > $1.date }).prefix(3).last?.id {
                        Divider()
                    }
                }
                if pet.vaccines.count > 3 {
                    NavigationLink {
                        VaccineListView(petId: pet.id)
                    } label: {
                        Text("Ver todas (\(pet.vaccines.count))")
                            .font(.appCaptionBold)
                            .foregroundStyle(Color.appPrimary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    // MARK: - Antiparasitics Card
    private var antiparasiticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Antiparasitarios", icon: "pills.fill", color: .appSecondary, addAction: { showingAddAntiparasitic = true })

            if pet.antiparasitics.isEmpty {
                emptyRowView("Sin antiparasitarios registrados", icon: "pills")
            } else {
                ForEach(pet.antiparasitics.sorted(by: { $0.date > $1.date }).prefix(3), id: \.id) { ap in
                    AntiparasiticRowView(antiparasitic: ap)
                    if ap.id != pet.antiparasitics.sorted(by: { $0.date > $1.date }).prefix(3).last?.id {
                        Divider()
                    }
                }
                if pet.antiparasitics.count > 3 {
                    NavigationLink {
                        AntiparasiticListView(petId: pet.id)
                    } label: {
                        Text("Ver todos (\(pet.antiparasitics.count))")
                            .font(.appCaptionBold)
                            .foregroundStyle(Color.appSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    // MARK: - Medical Card
    private var medicalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Historial Médico", icon: "stethoscope", color: .appTertiary, addAction: { showingAddMedicalRecord = true })

            if pet.medicalRecords.isEmpty {
                emptyRowView("Sin consultas registradas", icon: "stethoscope")
            } else {
                ForEach(pet.medicalRecords.sorted(by: { $0.date > $1.date }).prefix(3), id: \.id) { record in
                    MedicalRecordRowView(record: record)
                    if record.id != pet.medicalRecords.sorted(by: { $0.date > $1.date }).prefix(3).last?.id {
                        Divider()
                    }
                }
                if pet.medicalRecords.count > 3 {
                    NavigationLink {
                        MedicalRecordListView(petId: pet.id)
                    } label: {
                        Text("Ver todas (\(pet.medicalRecords.count))")
                            .font(.appCaptionBold)
                            .foregroundStyle(Color.appTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    // MARK: - Weight Card
    private var weightCard: some View {
        NavigationLink {
            WeightTrackingView(petId: pet.id)
        } label: {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 40, height: 40)
                    .background(Color.appBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Seguimiento de Peso")
                        .font(.appHeadline)
                        .foregroundStyle(.primary)
                    Text(pet.weight > 0 ? "Último: \(String(format: "%.1f kg", pet.weight))" : "Sin registros")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func emptyRowView(_ text: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(.vertical, 4)
    }
}

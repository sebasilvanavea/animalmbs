import SwiftUI

struct MedicalRecordListView: View {
    @Environment(PetStore.self) private var petStore
    let petId: UUID
    @State private var showingAdd = false

    private var pet: Pet? { petStore.pet(id: petId) }

    var sortedRecords: [MedicalRecord] {
        (pet?.medicalRecords ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            PawPrintBackground(opacity: 0.03, count: 8)

            if sortedRecords.isEmpty {
                EmptyStateView(
                    icon: "stethoscope",
                    title: "Sin consultas",
                    subtitle: "Registra la primera consulta de \(pet?.name ?? "") para mantener su historial completo",
                    actionTitle: "Agregar Consulta"
                ) {
                    showingAdd = true
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedRecords, id: \.id) { record in
                            NavigationLink {
                                MedicalRecordDetailView(record: record)
                            } label: {
                                MedicalRecordRowView(record: record)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Historial Médico")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.appSecondary)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddMedicalRecordView(petId: petId)
        }
    }
}

struct MedicalRecordRowView: View {
    let record: MedicalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.appSecondary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "stethoscope")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.reason)
                        .font(.appHeadline)
                        .foregroundStyle(.primary)
                    if !record.veterinarian.isEmpty {
                        Text(record.veterinarian)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                InfoChip(icon: "calendar", text: record.date.formatted(date: .abbreviated, time: .omitted), color: .appBlue)
            }

            if !record.diagnosis.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.document")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTertiary)
                    Text(record.diagnosis)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding()
        .cardStyle()
    }
}

struct MedicalRecordDetailView: View {
    let record: MedicalRecord

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.appSecondary.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "stethoscope")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.appSecondary)
                        }
                        Text(record.reason)
                            .font(.appHeadline)
                        Text(record.date.formatted(date: .long, time: .omitted))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    // Diagnosis
                    if !record.diagnosis.isEmpty {
                        detailCard(title: "Diagnóstico", icon: "text.document", color: .appTertiary) {
                            Text(record.diagnosis)
                                .font(.appBody)
                        }
                    }

                    // Treatment
                    if !record.treatment.isEmpty {
                        detailCard(title: "Tratamiento", icon: "cross.case", color: .appPrimary) {
                            Text(record.treatment)
                                .font(.appBody)
                        }
                    }

                    // Vet info
                    if !record.veterinarian.isEmpty || !record.clinicName.isEmpty {
                        detailCard(title: "Veterinario", icon: "person.text.rectangle", color: .appBlue) {
                            VStack(alignment: .leading, spacing: 8) {
                                if !record.veterinarian.isEmpty {
                                    Label(record.veterinarian, systemImage: "person")
                                        .font(.appBody)
                                }
                                if !record.clinicName.isEmpty {
                                    Label(record.clinicName, systemImage: "building.2")
                                        .font(.appBody)
                                }
                            }
                        }
                    }

                    // Notes
                    if !record.notes.isEmpty {
                        detailCard(title: "Notas", icon: "note.text", color: .appSecondary) {
                            Text(record.notes)
                                .font(.appBody)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Detalle Consulta")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.appHeadline)
                .foregroundStyle(color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

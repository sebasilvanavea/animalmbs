import SwiftUI

struct VaccineListView: View {
    @Environment(PetStore.self) private var petStore
    let petId: UUID
    @State private var showingAddVaccine = false

    private var pet: Pet? { petStore.pet(id: petId) }

    var sortedVaccines: [Vaccine] {
        (pet?.vaccines ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            PawPrintBackground(opacity: 0.03, count: 8)

            if sortedVaccines.isEmpty {
                EmptyStateView(
                    icon: "syringe",
                    title: "Sin vacunas",
                    subtitle: "Agrega la primera vacuna de \(pet?.name ?? "") para llevar un control completo",
                    actionTitle: "Agregar Vacuna"
                ) {
                    showingAddVaccine = true
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedVaccines, id: \.id) { vaccine in
                            VaccineRowView(vaccine: vaccine)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Vacunas de \(pet?.name ?? "")")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddVaccine = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.appPrimary)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddVaccine) {
            AddVaccineView(petId: petId)
        }
    }
}

struct VaccineRowView: View {
    let vaccine: Vaccine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(vaccine.isOverdue ? Color.appDanger.opacity(0.15) : Color.appPrimary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(vaccine.isOverdue ? Color.appDanger : Color.appPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(vaccine.name)
                        .font(.appHeadline)
                    if !vaccine.veterinarian.isEmpty {
                        Text(vaccine.veterinarian)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if vaccine.isOverdue {
                    StatusBadge(text: "VENCIDA", color: .appDanger, icon: "exclamationmark.triangle.fill")
                }
            }

            Divider()

            HStack {
                InfoChip(icon: "calendar", text: vaccine.date.formatted(date: .abbreviated, time: .omitted), color: .appBlue)

                if let nextDose = vaccine.nextDoseDate {
                    Spacer()
                    InfoChip(
                        icon: "arrow.forward.circle",
                        text: nextDose.formatted(date: .abbreviated, time: .omitted),
                        color: vaccine.isOverdue ? .appDanger : .appSecondary
                    )
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

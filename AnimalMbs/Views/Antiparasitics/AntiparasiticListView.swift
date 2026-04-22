import SwiftUI

struct AntiparasiticListView: View {
    @Environment(PetStore.self) private var petStore
    let petId: UUID
    @State private var showingAdd = false

    private var pet: Pet? { petStore.pet(id: petId) }

    var sortedItems: [Antiparasitic] {
        (pet?.antiparasitics ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            PawPrintBackground(opacity: 0.03, count: 8)

            if sortedItems.isEmpty {
                EmptyStateView(
                    icon: "pills",
                    title: "Sin antiparasitarios",
                    subtitle: "Registra el primer antiparasitario de \(pet?.name ?? "") para mantenerlo protegido",
                    actionTitle: "Agregar Antiparasitario"
                ) {
                    showingAdd = true
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedItems, id: \.id) { item in
                            AntiparasiticRowView(antiparasitic: item)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Antiparasitarios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.appTertiary)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddAntiparasiticView(petId: petId)
        }
    }
}

struct AntiparasiticRowView: View {
    let antiparasitic: Antiparasitic

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(antiparasitic.isOverdue ? Color.appDanger.opacity(0.15) : Color.appTertiary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: antiparasitic.type.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(antiparasitic.isOverdue ? Color.appDanger : Color.appTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(antiparasitic.productName)
                        .font(.appHeadline)
                }

                Spacer()

                InfoChip(icon: antiparasitic.type.icon, text: antiparasitic.type.rawValue, color: .appTertiary)

                if antiparasitic.isOverdue {
                    StatusBadge(text: "VENCIDA", color: .appDanger, icon: "exclamationmark.triangle.fill")
                }
            }

            Divider()

            HStack {
                InfoChip(icon: "calendar", text: antiparasitic.date.formatted(date: .abbreviated, time: .omitted), color: .appBlue)

                if let nextDate = antiparasitic.nextApplicationDate {
                    Spacer()
                    InfoChip(
                        icon: "arrow.forward.circle",
                        text: nextDate.formatted(date: .abbreviated, time: .omitted),
                        color: antiparasitic.isOverdue ? .appDanger : .appSecondary
                    )
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

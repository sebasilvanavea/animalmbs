import SwiftUI

struct RemindersView: View {
    @Environment(PetStore.self) private var petStore

    var upcomingVaccines: [(pet: Pet, vaccine: Vaccine)] {
        var results: [(pet: Pet, vaccine: Vaccine)] = []
        for pet in petStore.pets {
            for vaccine in pet.vaccines {
                if let nextDate = vaccine.nextDoseDate {
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
                    if daysUntil <= 30 || vaccine.isOverdue {
                        results.append((pet: pet, vaccine: vaccine))
                    }
                }
            }
        }
        return results.sorted { ($0.vaccine.nextDoseDate ?? .distantFuture) < ($1.vaccine.nextDoseDate ?? .distantFuture) }
    }

    var upcomingAntiparasitics: [(pet: Pet, antiparasitic: Antiparasitic)] {
        var results: [(pet: Pet, antiparasitic: Antiparasitic)] = []
        for pet in petStore.pets {
            for ap in pet.antiparasitics {
                if let nextDate = ap.nextApplicationDate {
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
                    if daysUntil <= 30 || ap.isOverdue {
                        results.append((pet: pet, antiparasitic: ap))
                    }
                }
            }
        }
        return results.sorted { ($0.antiparasitic.nextApplicationDate ?? .distantFuture) < ($1.antiparasitic.nextApplicationDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                PawPrintBackground(opacity: 0.03, count: 10)

                if upcomingVaccines.isEmpty && upcomingAntiparasitics.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "Sin recordatorios",
                        subtitle: "No hay vacunas ni antiparasitarios pendientes en los próximos 30 días. ¡Todo al día! 🎉"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Vaccines section
                            if !upcomingVaccines.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Vacunas Pendientes", systemImage: "syringe")
                                        .font(.appHeadline)
                                        .foregroundStyle(Color.appPrimary)
                                        .padding(.horizontal)

                                    ForEach(upcomingVaccines, id: \.vaccine.id) { item in
                                        ReminderCard(
                                            icon: "syringe.fill",
                                            title: item.vaccine.name,
                                            subtitle: item.pet.name,
                                            date: item.vaccine.nextDoseDate,
                                            isOverdue: item.vaccine.isOverdue,
                                            color: .appPrimary,
                                            daysText: daysUntilText(item.vaccine.nextDoseDate)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // Antiparasitics section
                            if !upcomingAntiparasitics.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Antiparasitarios Pendientes", systemImage: "pills")
                                        .font(.appHeadline)
                                        .foregroundStyle(Color.appTertiary)
                                        .padding(.horizontal)

                                    ForEach(upcomingAntiparasitics, id: \.antiparasitic.id) { item in
                                        ReminderCard(
                                            icon: item.antiparasitic.type.icon,
                                            title: item.antiparasitic.productName,
                                            subtitle: "\(item.pet.name) • \(item.antiparasitic.type.rawValue)",
                                            date: item.antiparasitic.nextApplicationDate,
                                            isOverdue: item.antiparasitic.isOverdue,
                                            color: .appTertiary,
                                            daysText: daysUntilText(item.antiparasitic.nextApplicationDate)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Recordatorios")
        }
    }

    private func daysUntilText(_ date: Date?) -> String {
        guard let date else { return "" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return "Hace \(abs(days)) día\(abs(days) == 1 ? "" : "s")" }
        if days == 0 { return "Hoy" }
        if days == 1 { return "Mañana" }
        return "En \(days) días"
    }
}

// MARK: - Reminder Card
private struct ReminderCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let date: Date?
    let isOverdue: Bool
    let color: Color
    let daysText: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isOverdue ? Color.appDanger.opacity(0.15) : color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isOverdue ? Color.appDanger : color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appHeadline)
                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if isOverdue {
                    StatusBadge(text: "VENCIDA", color: .appDanger, icon: "exclamationmark.triangle.fill")
                }
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.appCaption)
                        .foregroundStyle(isOverdue ? Color.appDanger : .primary)
                }
                Text(daysText)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .cardStyle()
    }
}

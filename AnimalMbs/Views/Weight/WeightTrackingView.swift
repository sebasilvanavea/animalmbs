import SwiftUI
import Charts

struct WeightTrackingView: View {
    @Environment(PetStore.self) private var petStore
    let petId: UUID
    @State private var showingAddWeight = false
    @State private var newWeight: Double = 0
    @State private var newDate = Date()
    @State private var newNotes = ""

    private var pet: Pet? { petStore.pet(id: petId) }

    var sortedEntries: [WeightEntry] {
        (pet?.weightHistory ?? []).sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            PawPrintBackground(opacity: 0.03, count: 6)

            ScrollView {
                VStack(spacing: 16) {
                    // Current weight header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.appBlue.opacity(0.15))
                                .frame(width: 70, height: 70)
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.appBlue)
                        }

                        if let pet, pet.weight > 0 {
                            Text(String(format: "%.1f kg", pet.weight))
                                .font(.appTitle)
                                .foregroundStyle(Color.appBlue)
                            Text("Peso actual")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    // Chart
                    if !sortedEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Evolución de Peso", systemImage: "chart.xyaxis.line")
                                .font(.appHeadline)
                                .foregroundStyle(Color.appBlue)

                            Chart(sortedEntries, id: \.id) { entry in
                                AreaMark(
                                    x: .value("Fecha", entry.date),
                                    y: .value("Peso", entry.weight)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.appBlue.opacity(0.3), Color.appBlue.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)

                                LineMark(
                                    x: .value("Fecha", entry.date),
                                    y: .value("Peso", entry.weight)
                                )
                                .foregroundStyle(Color.appBlue)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))

                                PointMark(
                                    x: .value("Fecha", entry.date),
                                    y: .value("Peso", entry.weight)
                                )
                                .foregroundStyle(Color.appBlue)
                                .symbolSize(40)
                            }
                            .chartYAxisLabel("kg")
                            .frame(height: 200)
                        }
                        .padding()
                        .cardStyle()
                        .padding(.horizontal)
                    }

                    // History header
                    SectionHeaderView(
                        title: "Historial",
                        icon: "list.bullet",
                        color: .appBlue,
                        showAdd: true
                    ) {
                        newWeight = pet?.weight ?? 0
                        showingAddWeight = true
                    }
                    .padding(.horizontal)

                    // Entries
                    if sortedEntries.isEmpty {
                        EmptyStateView(
                            icon: "scalemass",
                            title: "Sin registros",
                            subtitle: "Registra el peso de \(pet?.name ?? "") para ver su evolución",
                            actionTitle: "Registrar Peso"
                        ) {
                            newWeight = pet?.weight ?? 0
                            showingAddWeight = true
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(sortedEntries.reversed(), id: \.id) { entry in
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.appBlue.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "scalemass")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.appBlue)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(format: "%.1f kg", entry.weight))
                                            .font(.appHeadline)
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.appCaption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if !entry.notes.isEmpty {
                                        Text(entry.notes)
                                            .font(.appCaption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding()
                                .cardStyle()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Peso de \(pet?.name ?? "")")
        .alert("Registrar Peso", isPresented: $showingAddWeight) {
            TextField("Peso (kg)", value: $newWeight, format: .number)
                .keyboardType(.decimalPad)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                saveWeight()
            }
        } message: {
            Text("Ingresa el peso actual de \(pet?.name ?? "") en kilogramos")
        }
    }

    private func saveWeight() {
        guard newWeight > 0 else { return }
        let entry = WeightEntry(date: newDate, weight: newWeight)
        Task {
            await petStore.addWeightEntry(entry, petId: petId)
        }
    }
}

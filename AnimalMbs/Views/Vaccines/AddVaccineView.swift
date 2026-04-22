import SwiftUI

struct AddVaccineView: View {
    @Environment(PetStore.self) private var petStore
    @Environment(\.dismiss) private var dismiss

    let petId: UUID

    @State private var name = ""
    @State private var selectedCommonVaccine: CommonVaccine?
    @State private var date = Date()
    @State private var hasNextDose = true
    @State private var nextDoseDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var veterinarian = ""
    @State private var clinicName = ""
    @State private var lotNumber = ""
    @State private var notes = ""
    @State private var isSaving = false

    private var petName: String { petStore.pet(id: petId)?.name ?? "" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.15))
                                .frame(width: 70, height: 70)
                            Image(systemName: "syringe.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.appPrimary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    Picker("Vacuna común", selection: $selectedCommonVaccine) {
                        Text("Personalizada").tag(nil as CommonVaccine?)
                        ForEach(CommonVaccine.allCases, id: \.self) { vaccine in
                            Text(vaccine.rawValue).tag(vaccine as CommonVaccine?)
                        }
                    }
                    .tint(Color.appPrimary)
                    .onChange(of: selectedCommonVaccine) { _, newValue in
                        if let newValue {
                            name = newValue.rawValue
                            nextDoseDate = Calendar.current.date(byAdding: .day, value: newValue.defaultIntervalDays, to: date) ?? date
                        }
                    }

                    if selectedCommonVaccine == nil {
                        TextField("Nombre de la vacuna", text: $name)
                    }
                } header: {
                    Label("Vacuna", systemImage: "cross.vial")
                        .sectionHeader(color: .appPrimary)
                }

                Section {
                    DatePicker("Fecha de aplicación", selection: $date, displayedComponents: .date)
                        .tint(Color.appPrimary)

                    Toggle("Próxima dosis", isOn: $hasNextDose)
                        .tint(Color.appPrimary)
                    if hasNextDose {
                        DatePicker("Fecha próxima dosis", selection: $nextDoseDate, displayedComponents: .date)
                            .tint(Color.appPrimary)
                    }
                } header: {
                    Label("Fechas", systemImage: "calendar")
                        .sectionHeader(color: .appBlue)
                }

                Section {
                    TextField("Nombre del veterinario", text: $veterinarian)
                    TextField("Clínica / Centro veterinario", text: $clinicName)
                } header: {
                    Label("Veterinario", systemImage: "person.text.rectangle")
                        .sectionHeader(color: .appTertiary)
                }

                Section {
                    TextField("Número de lote", text: $lotNumber)
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Label("Detalles", systemImage: "doc.text")
                        .sectionHeader(color: .appSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Nueva Vacuna")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.appDanger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : Color.appPrimary)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let vaccine = Vaccine(
            name: name.trimmingCharacters(in: .whitespaces),
            date: date,
            nextDoseDate: hasNextDose ? nextDoseDate : nil,
            veterinarian: veterinarian,
            clinicName: clinicName,
            lotNumber: lotNumber,
            notes: notes
        )

        if hasNextDose {
            NotificationManager.shared.scheduleVaccineReminder(
                petName: petName,
                vaccineName: name,
                date: nextDoseDate
            )
        }

        Task {
            await petStore.addVaccine(vaccine, petId: petId)
            await MainActor.run { dismiss() }
        }
    }
}

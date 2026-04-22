import SwiftUI

struct AddAntiparasiticView: View {
    @Environment(PetStore.self) private var petStore
    @Environment(\.dismiss) private var dismiss

    let petId: UUID

    @State private var type: AntiparasiticType = .internal_
    @State private var productName = ""
    @State private var selectedCommon: CommonAntiparasitic?
    @State private var date = Date()
    @State private var hasNextDate = true
    @State private var nextApplicationDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var veterinarian = ""
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
                                .fill(Color.appTertiary.opacity(0.15))
                                .frame(width: 70, height: 70)
                            Image(systemName: "pills.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.appTertiary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    Picker("Tipo", selection: $type) {
                        ForEach(AntiparasiticType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Tipo", systemImage: "tag")
                        .sectionHeader(color: .appTertiary)
                }

                Section {
                    Picker("Producto común", selection: $selectedCommon) {
                        Text("Personalizado").tag(nil as CommonAntiparasitic?)
                        ForEach(CommonAntiparasitic.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p as CommonAntiparasitic?)
                        }
                    }
                    .tint(Color.appTertiary)
                    .onChange(of: selectedCommon) { _, newValue in
                        if let newValue {
                            productName = newValue.rawValue
                        }
                    }

                    if selectedCommon == nil {
                        TextField("Nombre del producto", text: $productName)
                    }
                } header: {
                    Label("Producto", systemImage: "cross.vial")
                        .sectionHeader(color: .appTertiary)
                }

                Section {
                    DatePicker("Fecha de aplicación", selection: $date, displayedComponents: .date)
                        .tint(Color.appTertiary)

                    Toggle("Próxima aplicación", isOn: $hasNextDate)
                        .tint(Color.appTertiary)
                    if hasNextDate {
                        DatePicker("Fecha", selection: $nextApplicationDate, displayedComponents: .date)
                            .tint(Color.appTertiary)
                    }
                } header: {
                    Label("Fechas", systemImage: "calendar")
                        .sectionHeader(color: .appBlue)
                }

                Section {
                    TextField("Nombre del veterinario", text: $veterinarian)
                } header: {
                    Label("Veterinario", systemImage: "person.text.rectangle")
                        .sectionHeader(color: .appPrimary)
                }

                Section {
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Label("Notas", systemImage: "note.text")
                        .sectionHeader(color: .appSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Nuevo Antiparasitario")
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
                    .disabled(productName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                    .foregroundStyle(productName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : Color.appTertiary)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let item = Antiparasitic(
            type: type,
            productName: productName.trimmingCharacters(in: .whitespaces),
            date: date,
            nextApplicationDate: hasNextDate ? nextApplicationDate : nil,
            veterinarian: veterinarian,
            notes: notes
        )

        if hasNextDate {
            NotificationManager.shared.scheduleAntiparasiticReminder(
                petName: petName,
                productName: productName,
                date: nextApplicationDate
            )
        }

        Task {
            await petStore.addAntiparasitic(item, petId: petId)
            await MainActor.run { dismiss() }
        }
    }
}

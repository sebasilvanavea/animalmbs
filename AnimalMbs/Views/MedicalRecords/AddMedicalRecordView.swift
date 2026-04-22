import SwiftUI

struct AddMedicalRecordView: View {
    @Environment(PetStore.self) private var petStore
    @Environment(\.dismiss) private var dismiss

    let petId: UUID

    @State private var date = Date()
    @State private var reason = ""
    @State private var diagnosis = ""
    @State private var treatment = ""
    @State private var veterinarian = ""
    @State private var clinicName = ""
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.appSecondary.opacity(0.15))
                                .frame(width: 70, height: 70)
                            Image(systemName: "stethoscope")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.appSecondary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                        .tint(Color.appSecondary)
                    TextField("Motivo de la consulta", text: $reason)
                } header: {
                    Label("Consulta", systemImage: "stethoscope")
                        .sectionHeader(color: .appSecondary)
                }

                Section {
                    TextField("Diagnóstico", text: $diagnosis, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Label("Diagnóstico", systemImage: "text.document")
                        .sectionHeader(color: .appTertiary)
                }

                Section {
                    TextField("Tratamiento indicado", text: $treatment, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Label("Tratamiento", systemImage: "cross.case")
                        .sectionHeader(color: .appPrimary)
                }

                Section {
                    TextField("Nombre del veterinario", text: $veterinarian)
                    TextField("Clínica / Centro veterinario", text: $clinicName)
                } header: {
                    Label("Veterinario", systemImage: "person.text.rectangle")
                        .sectionHeader(color: .appBlue)
                }

                Section {
                    TextField("Notas adicionales", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Label("Notas", systemImage: "note.text")
                        .sectionHeader(color: .appSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Nueva Consulta")
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
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                    .foregroundStyle(reason.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : Color.appSecondary)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let record = MedicalRecord(
            date: date,
            reason: reason.trimmingCharacters(in: .whitespaces),
            diagnosis: diagnosis,
            treatment: treatment,
            veterinarian: veterinarian,
            clinicName: clinicName,
            notes: notes
        )

        Task {
            await petStore.addMedicalRecord(record, petId: petId)
            await MainActor.run { dismiss() }
        }
    }
}

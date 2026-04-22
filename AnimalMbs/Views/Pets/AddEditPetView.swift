import SwiftUI
import PhotosUI

struct AddEditPetView: View {
    @Environment(PetStore.self) private var petStore
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    var pet: Pet?

    @State private var name = ""
    @State private var species: PetSpecies = .dog
    @State private var breed = ""
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    @State private var sex: PetSex = .unknown
    @State private var color = ""
    @State private var weight: Double = 0
    @State private var microchipNumber = ""
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var originalPhotoData: Data?
    @State private var isSaving = false

    var isEditing: Bool { pet != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Photo section
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let photoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(species.themeColor.opacity(0.3), lineWidth: 3)
                                    )
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white)
                                            .padding(8)
                                            .background(species.themeColor)
                                            .clipShape(Circle())
                                            .offset(x: 35, y: 35)
                                    )
                            } else {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(species.gradient)
                                            .frame(width: 110, height: 110)
                                        Image(systemName: species.icon)
                                            .font(.system(size: 44))
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: species.themeColor.opacity(0.3), radius: 6, y: 3)

                                    Text("Agregar foto")
                                        .font(.appCaption)
                                        .foregroundStyle(species.themeColor)
                                }
                            }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // Basic info
                Section {
                    TextField("Nombre", text: $name)

                    Picker("Especie", selection: $species) {
                        ForEach(PetSpecies.allCases, id: \.self) { sp in
                            Label(sp.rawValue, systemImage: sp.icon)
                                .tag(sp)
                        }
                    }
                    .tint(species.themeColor)

                    TextField("Raza", text: $breed)

                    Picker("Sexo", selection: $sex) {
                        ForEach(PetSex.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .tint(species.themeColor)
                } header: {
                    Label("Datos Básicos", systemImage: "pawprint")
                        .sectionHeader(color: species.themeColor)
                }

                // Birth date
                Section {
                    Toggle("Conocida", isOn: $hasBirthDate)
                        .tint(species.themeColor)
                    if hasBirthDate {
                        DatePicker("Fecha", selection: $birthDate, displayedComponents: .date)
                            .tint(species.themeColor)
                    }
                } header: {
                    Label("Fecha de Nacimiento", systemImage: "birthday.cake")
                        .sectionHeader(color: .appSecondary)
                }

                // Physical data
                Section {
                    HStack {
                        Text("Peso (kg)")
                        Spacer()
                        TextField("0.0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    TextField("Color", text: $color)
                } header: {
                    Label("Datos Físicos", systemImage: "scalemass")
                        .sectionHeader(color: .appBlue)
                }

                // ID
                Section {
                    TextField("Número de microchip", text: $microchipNumber)
                } header: {
                    Label("Identificación", systemImage: "cpu")
                        .sectionHeader(color: .appTertiary)
                }

                // Notes
                Section {
                    TextField("Notas adicionales", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Label("Notas", systemImage: "note.text")
                        .sectionHeader(color: .appSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Editar Mascota" : "Nueva Mascota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appDanger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : species.themeColor)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear {
                if let pet {
                    name = pet.name
                    species = pet.species
                    breed = pet.breed
                    sex = pet.sex
                    color = pet.color
                    weight = pet.weight
                    microchipNumber = pet.microchipNumber
                    notes = pet.notes
                    photoData = pet.photoData
                    originalPhotoData = pet.photoData
                    if let bd = pet.birthDate {
                        hasBirthDate = true
                        birthDate = bd
                    }
                } else {
                    originalPhotoData = nil
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let petToSave = Pet(
            id: pet?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            species: species,
            breed: breed,
            birthDate: hasBirthDate ? birthDate : nil,
            sex: sex,
            color: color,
            weight: weight,
            microchipNumber: microchipNumber,
            photoData: photoData,
            notes: notes
        )

        Task {
            let hasPhotoChanged = photoData != originalPhotoData
            let photoToUpload = hasPhotoChanged ? photoData : nil
            await petStore.savePet(petToSave, userId: authManager.currentUserId ?? UUID(), photoData: photoToUpload)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

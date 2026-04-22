import Foundation

@Observable
final class PetStore {
    var pets: [Pet] = []
    var isLoading = false
    var errorMessage: String?

    private let client = SupabaseClient.shared

    // MARK: - Pets

    func loadPets() async {
        isLoading = true
        errorMessage = nil
        do {
            var loadedPets: [Pet] = try await client.fetch("pets", order: "name.asc")
            // Load photo data: prefer Supabase Storage URL, fallback to local cache.
            // This keeps iOS aligned with web, which renders directly from photo_url.
            for i in loadedPets.indices {
                if let urlStr = loadedPets[i].photoUrl,
                   let url = URL(string: urlStr),
                   let (data, response) = try? await URLSession.shared.data(from: url),
                   let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    loadedPets[i].photoData = data
                    PhotoStorage.shared.save(data, petId: loadedPets[i].id)
                } else if let localData = PhotoStorage.shared.load(petId: loadedPets[i].id) {
                    loadedPets[i].photoData = localData
                }
            }
            // Swift 6: capture as let to avoid mutable var capture in concurrent closure
            let finalPets = loadedPets
            await MainActor.run {
                self.pets = finalPets
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func loadPetDetails(_ petId: UUID) async {
        do {
            let vaccines: [Vaccine] = try await client.fetch("vaccines", query: ["pet_id": "eq.\(petId.uuidString)"], order: "date.desc")
            let antiparasitics: [Antiparasitic] = try await client.fetch("antiparasitics", query: ["pet_id": "eq.\(petId.uuidString)"], order: "date.desc")
            let medicalRecords: [MedicalRecord] = try await client.fetch("medical_records", query: ["pet_id": "eq.\(petId.uuidString)"], order: "date.desc")
            let weightEntries: [WeightEntry] = try await client.fetch("weight_entries", query: ["pet_id": "eq.\(petId.uuidString)"], order: "date.desc")

            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].vaccines = vaccines
                    self.pets[idx].antiparasitics = antiparasitics
                    self.pets[idx].medicalRecords = medicalRecords
                    self.pets[idx].weightHistory = weightEntries
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func pet(id: UUID) -> Pet? {
        pets.first { $0.id == id }
    }

    func savePet(_ pet: Pet, userId: UUID, photoData: Data?) async {
        do {
            var petToSave = pet
            petToSave.userId = userId
            let existingPet = pets.first { $0.id == pet.id }

            // Upload only when the caller is explicitly saving new photo bytes.
            // Otherwise preserve the remote photo_url already stored in Supabase.
            if let photoData {
                let photoUrl = try await client.uploadPhoto(photoData, userId: userId, petId: pet.id)
                petToSave.photoUrl = photoUrl
            } else {
                petToSave.photoUrl = existingPet?.photoUrl ?? pet.photoUrl
            }

            if pets.contains(where: { $0.id == pet.id }) {
                // Update
                let updated: Pet = try await client.update("pets", id: pet.id, row: petToSave)
                await MainActor.run {
                    if let idx = self.pets.firstIndex(where: { $0.id == pet.id }) {
                        let currentPet = self.pets[idx]
                        self.pets[idx] = updated
                        self.pets[idx].vaccines = currentPet.vaccines
                        self.pets[idx].antiparasitics = currentPet.antiparasitics
                        self.pets[idx].medicalRecords = currentPet.medicalRecords
                        self.pets[idx].weightHistory = currentPet.weightHistory
                        self.pets[idx].photoData = photoData ?? currentPet.photoData
                    }
                }
            } else {
                // Insert
                let inserted: Pet = try await client.insert("pets", row: petToSave)
                await MainActor.run {
                    var newPet = inserted
                    newPet.photoData = photoData
                    self.pets.append(newPet)
                    self.pets.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
                }
            }

            // Save photo locally
            if let photoData {
                PhotoStorage.shared.save(photoData, petId: pet.id)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deletePet(_ petId: UUID) async {
        do {
            // Best-effort: delete photo from Supabase Storage
            if let pet = pet(id: petId), let userId = pet.userId {
                try? await client.deletePhoto(userId: userId, petId: petId)
            }
            try await client.delete("pets", id: petId)
            PhotoStorage.shared.delete(petId: petId)
            await MainActor.run {
                self.pets.removeAll { $0.id == petId }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Vaccines

    func addVaccine(_ vaccine: Vaccine, petId: UUID) async {
        do {
            var v = vaccine
            v.petId = petId
            let inserted: Vaccine = try await client.insert("vaccines", row: v)
            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].vaccines.insert(inserted, at: 0)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteVaccine(_ vaccineId: UUID, petId: UUID) async {
        do {
            try await client.delete("vaccines", id: vaccineId)
            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].vaccines.removeAll { $0.id == vaccineId }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Antiparasitics

    func addAntiparasitic(_ antiparasitic: Antiparasitic, petId: UUID) async {
        do {
            var a = antiparasitic
            a.petId = petId
            let inserted: Antiparasitic = try await client.insert("antiparasitics", row: a)
            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].antiparasitics.insert(inserted, at: 0)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteAntiparasitic(_ antiparasiticId: UUID, petId: UUID) async {
        do {
            try await client.delete("antiparasitics", id: antiparasiticId)
            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].antiparasitics.removeAll { $0.id == antiparasiticId }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Medical Records

    func addMedicalRecord(_ record: MedicalRecord, petId: UUID) async {
        do {
            var r = record
            r.petId = petId
            let inserted: MedicalRecord = try await client.insert("medical_records", row: r)
            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].medicalRecords.insert(inserted, at: 0)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteMedicalRecord(_ recordId: UUID, petId: UUID) async {
        do {
            try await client.delete("medical_records", id: recordId)
            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].medicalRecords.removeAll { $0.id == recordId }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Weight Entries

    func addWeightEntry(_ entry: WeightEntry, petId: UUID) async {
        do {
            var w = entry
            w.petId = petId
            let inserted: WeightEntry = try await client.insert("weight_entries", row: w)
            await MainActor.run {
                if let idx = self.pets.firstIndex(where: { $0.id == petId }) {
                    self.pets[idx].weightHistory.insert(inserted, at: 0)
                    self.pets[idx].weight = entry.weight
                }
            }
            // Also update the pet's weight in the DB
            if let pet = pet(id: petId) {
                var updatedPet = pet
                updatedPet.weight = entry.weight
                let _: Pet = try await client.update("pets", id: petId, row: updatedPet)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

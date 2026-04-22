import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeGenerator {
    /// Base URL for the web viewer deployed on Netlify.
    static let webBaseURL = "https://animalm.netlify.app"

    static func generate(from string: String, size: CGFloat = 250) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Generates a web URL with the pet's clinical data encoded as base64url in the query string.
    /// Anyone scanning the QR can view the clinical record on web, iOS, or Android.
    static func webURL(for pet: Pet) -> String {
        let jsonString = petClinicalData(for: pet)
        let base64 = Data(jsonString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(webBaseURL)?d=\(base64)"
    }

    static func petClinicalData(for pet: Pet) -> String {
        var data: [String: Any] = [
            "app": "AnimalMbs",
            "v": 2,
            "pet": [
                "name": pet.name,
                "species": pet.species.rawValue,
                "breed": pet.breed,
                "sex": pet.sex.rawValue,
                "age": pet.age,
                "weight": pet.weight,
                "microchip": pet.microchipNumber,
                "color": pet.color
            ]
        ]

        // All vaccines (full data)
        let vaccineData = pet.vaccines
            .sorted { $0.date > $1.date }
            .map { v -> [String: Any] in
                var entry: [String: Any] = [
                    "n": v.name,
                    "d": formatDate(v.date)
                ]
                if let next = v.nextDoseDate {
                    entry["nx"] = formatDate(next)
                }
                if !v.lotNumber.isEmpty { entry["l"] = v.lotNumber }
                if !v.veterinarian.isEmpty { entry["vet"] = v.veterinarian }
                if !v.clinicName.isEmpty { entry["cl"] = v.clinicName }
                if !v.notes.isEmpty { entry["nt"] = v.notes }
                return entry
            }
        if !vaccineData.isEmpty {
            data["vac"] = vaccineData
        }

        // All antiparasitics (full data)
        let apData = pet.antiparasitics
            .sorted { $0.date > $1.date }
            .map { a -> [String: Any] in
                var entry: [String: Any] = [
                    "n": a.productName,
                    "t": a.type.rawValue,
                    "d": formatDate(a.date)
                ]
                if let next = a.nextApplicationDate {
                    entry["nx"] = formatDate(next)
                }
                if !a.veterinarian.isEmpty { entry["vet"] = a.veterinarian }
                if !a.notes.isEmpty { entry["nt"] = a.notes }
                return entry
            }
        if !apData.isEmpty {
            data["ap"] = apData
        }

        // All medical records (full data)
        let mrData = pet.medicalRecords
            .sorted { $0.date > $1.date }
            .map { r -> [String: Any] in
                var entry: [String: Any] = [
                    "r": r.reason,
                    "d": formatDate(r.date)
                ]
                if !r.diagnosis.isEmpty { entry["dx"] = r.diagnosis }
                if !r.treatment.isEmpty { entry["tx"] = r.treatment }
                if !r.veterinarian.isEmpty { entry["vet"] = r.veterinarian }
                if !r.clinicName.isEmpty { entry["cl"] = r.clinicName }
                if !r.notes.isEmpty { entry["nt"] = r.notes }
                return entry
            }
        if !mrData.isEmpty {
            data["med"] = mrData
        }

        // Weight history
        let weightData = pet.weightHistory
            .sorted { $0.date > $1.date }
            .map { w -> [String: Any] in
                var entry: [String: Any] = [
                    "w": w.weight,
                    "d": formatDate(w.date)
                ]
                if !w.notes.isEmpty { entry["nt"] = w.notes }
                return entry
            }
        if !weightData.isEmpty {
            data["wt"] = weightData
        }

        data["gen"] = formatDate(Date())

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "AnimalMbs: \(pet.name)"
        }

        return jsonString
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
}

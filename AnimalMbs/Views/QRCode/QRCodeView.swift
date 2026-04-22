import SwiftUI

struct QRCodeView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        PetAvatar(pet: pet, size: 70)
                        Text(pet.name)
                            .font(.appTitle)
                        Text("Hoja Clínica Digital")
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                    }

                    // QR Code
                    if let qrImage {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.appCardBackground)
                                .shadow(color: .black.opacity(0.12), radius: 15, y: 5)

                            VStack(spacing: 12) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 220)
                                    .padding(20)

                                HStack(spacing: 4) {
                                    Image(systemName: "pawprint.fill")
                                        .font(.caption2)
                                    Text("AnimalMbs")
                                        .font(.appCaptionBold)
                                }
                                .foregroundStyle(Color.appPrimary)
                                .padding(.bottom, 12)
                            }
                        }
                        .frame(width: 280, height: 310)
                    } else {
                        PawLoader()
                            .frame(height: 280)
                    }

                    // Info
                    VStack(spacing: 6) {
                        Label("Escanea para ver la ficha en cualquier dispositivo", systemImage: "qrcode.viewfinder")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.appTextSecondary)

                        Text("Funciona en Web, iOS y Android")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextTertiary)
                            .multilineTextAlignment(.center)
                    }

                    // Actions
                    VStack(spacing: 12) {
                        // Share PDF button
                        if let pdfURL {
                            ShareLink(
                                item: pdfURL,
                                preview: SharePreview("Ficha Clínica - \(pet.name)", image: Image(systemName: "doc.fill"))
                            ) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                    Text("Compartir Ficha Clínica (PDF)")
                                }
                                .font(.appHeadline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.appPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        // Share QR image
                        if let qrImage {
                            ShareLink(
                                item: Image(uiImage: qrImage),
                                preview: SharePreview("QR Clínico - \(pet.name)", image: Image(uiImage: qrImage))
                            ) {
                                HStack {
                                    Image(systemName: "qrcode")
                                    Text("Compartir imagen QR")
                                }
                                .font(.appHeadline)
                                .foregroundStyle(Color.appPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.appPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("QR Clínico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear {
                generateQR()
                generatePDF()
            }
        }
    }

    private func generateQR() {
        let url = QRCodeGenerator.webURL(for: pet)
        qrImage = QRCodeGenerator.generate(from: url, size: 500)
    }

    @MainActor
    private func generatePDF() {
        let pdfView = ClinicalPDFContent(pet: pet)
        let renderer = ImageRenderer(content: pdfView)
        renderer.scale = 2.0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FichaClinica_\(pet.name).pdf")

        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(tempURL as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }

        self.pdfURL = tempURL
    }
}

// MARK: - PDF Content View (reusable)
struct ClinicalPDFContent: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cross.case.fill").font(.title)
                Text("HOJA CLÍNICA VETERINARIA").font(.title2.bold())
                Spacer()
                Image(systemName: "pawprint.fill").font(.title2).foregroundStyle(.gray)
            }

            Divider()

            Text("DATOS DEL PACIENTE").font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                GridRow {
                    Text("Nombre: \(pet.name)").font(.body)
                    Text("Especie: \(pet.species.rawValue)").font(.body)
                }
                GridRow {
                    Text("Raza: \(pet.breed.isEmpty ? "N/E" : pet.breed)").font(.body)
                    Text("Sexo: \(pet.sex.rawValue)").font(.body)
                }
                GridRow {
                    Text("Edad: \(pet.age)").font(.body)
                    Text("Peso: \(pet.weight > 0 ? String(format: "%.1f kg", pet.weight) : "N/R")").font(.body)
                }
                GridRow {
                    Text("Microchip: \(pet.microchipNumber.isEmpty ? "N/R" : pet.microchipNumber)").font(.body)
                    Text("Color: \(pet.color.isEmpty ? "N/E" : pet.color)").font(.body)
                }
            }

            if !pet.vaccines.isEmpty {
                Divider()
                Text("VACUNAS").font(.headline)
                ForEach(pet.vaccines.sorted(by: { $0.date > $1.date }), id: \.id) { v in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• \(v.name) - \(v.date.formatted(date: .abbreviated, time: .omitted))\(v.lotNumber.isEmpty ? "" : " (Lote: \(v.lotNumber))")")
                            .font(.body.bold())
                        if let next = v.nextDoseDate {
                            Text("  Próxima dosis: \(next.formatted(date: .abbreviated, time: .omitted))")
                                .font(.body)
                        }
                        if !v.veterinarian.isEmpty {
                            Text("  Veterinario: \(v.veterinarian)").font(.body)
                        }
                        if !v.clinicName.isEmpty {
                            Text("  Clínica: \(v.clinicName)").font(.body)
                        }
                        if !v.notes.isEmpty {
                            Text("  Notas: \(v.notes)").font(.body).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !pet.antiparasitics.isEmpty {
                Divider()
                Text("ANTIPARASITARIOS").font(.headline)
                ForEach(pet.antiparasitics.sorted(by: { $0.date > $1.date }), id: \.id) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• \(a.productName) (\(a.type.rawValue)) - \(a.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.body.bold())
                        if let next = a.nextApplicationDate {
                            Text("  Próxima aplicación: \(next.formatted(date: .abbreviated, time: .omitted))")
                                .font(.body)
                        }
                        if !a.veterinarian.isEmpty {
                            Text("  Veterinario: \(a.veterinarian)").font(.body)
                        }
                        if !a.notes.isEmpty {
                            Text("  Notas: \(a.notes)").font(.body).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !pet.medicalRecords.isEmpty {
                Divider()
                Text("HISTORIAL MÉDICO").font(.headline)
                ForEach(pet.medicalRecords.sorted(by: { $0.date > $1.date }), id: \.id) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• \(r.reason) - \(r.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.body.bold())
                        if !r.diagnosis.isEmpty {
                            Text("  Diagnóstico: \(r.diagnosis)").font(.body)
                        }
                        if !r.treatment.isEmpty {
                            Text("  Tratamiento: \(r.treatment)").font(.body)
                        }
                        if !r.veterinarian.isEmpty {
                            Text("  Veterinario: \(r.veterinarian)").font(.body)
                        }
                        if !r.clinicName.isEmpty {
                            Text("  Clínica: \(r.clinicName)").font(.body)
                        }
                        if !r.notes.isEmpty {
                            Text("  Notas: \(r.notes)").font(.body).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !pet.weightHistory.isEmpty {
                Divider()
                Text("HISTORIAL DE PESO").font(.headline)
                ForEach(pet.weightHistory.sorted(by: { $0.date > $1.date }), id: \.id) { w in
                    HStack {
                        Text("• \(w.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.1f kg", w.weight))
                            .font(.body.bold())
                    }
                }
            }

            // QR Code embedded
            Divider()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    if let qrImage = QRCodeGenerator.generate(
                        from: QRCodeGenerator.webURL(for: pet),
                        size: 150
                    ) {
                        Text("ESCANEA PARA VER LA FICHA CLÍNICA")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                        Text("AnimalMbs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Divider()
            Text("Generado por AnimalMbs - \(Date().formatted(date: .long, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(40)
        .frame(width: 595)
        .background(.white)
    }
}

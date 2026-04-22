import SwiftUI
import PDFKit

struct ClinicalRecordView: View {
    @Environment(\.dismiss) private var dismiss
    let pet: Pet
    @State private var showingQR = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    patientInfoSection

                    if !pet.vaccines.isEmpty { vaccinesSection }
                    if !pet.antiparasitics.isEmpty { antiparasiticsSection }
                    if !pet.medicalRecords.isEmpty { medicalRecordsSection }
                    if !pet.weightHistory.isEmpty { weightSection }

                    // QR Button
                    qrSection
                    footerSection
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Hoja Clínica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: generatePDFForShare(), preview: SharePreview("Hoja Clínica - \(pet.name)", image: Image(systemName: "doc.fill"))) {
                        Label("Exportar PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingQR) {
                QRCodeView(pet: pet)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "cross.case.fill")
                    .font(.title)
                    .foregroundStyle(Color.appPrimary)
                VStack(alignment: .leading) {
                    Text("HOJA CLÍNICA VETERINARIA")
                        .font(.system(.headline, design: .rounded))
                    Text("AnimalMbs")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(Color.appPrimary.opacity(0.3))
            }
            .padding()
            .background(Color.appPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var patientInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            clinicalSectionTitle("DATOS DEL PACIENTE", icon: "person.fill", color: .appPrimary)

            HStack(spacing: 14) {
                PetAvatar(pet: pet, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name).font(.system(.title3, design: .rounded).bold())
                    Text("\(pet.species.rawValue) • \(pet.breed.isEmpty ? "Sin raza" : pet.breed)")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            infoGrid([
                ("Sexo", pet.sex.rawValue),
                ("Edad", pet.age),
                ("Peso", pet.weight > 0 ? String(format: "%.1f kg", pet.weight) : "No registrado"),
                ("Color", pet.color.isEmpty ? "No especificado" : pet.color),
                ("Microchip", pet.microchipNumber.isEmpty ? "No registrado" : pet.microchipNumber),
            ])
        }
        .padding(14)
        .cardStyle()
    }

    private var vaccinesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            clinicalSectionTitle("VACUNAS", icon: "syringe.fill", color: .appPrimary)

            ForEach(pet.vaccines.sorted(by: { $0.date > $1.date }), id: \.id) { vaccine in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(vaccine.name)
                            .font(.system(.subheadline, design: .rounded).bold())
                        Spacer()
                        Text(vaccine.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                    if let nextDose = vaccine.nextDoseDate {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.forward.circle.fill")
                                .font(.caption2)
                            Text("Próxima: \(nextDose.formatted(date: .abbreviated, time: .omitted))")
                                .font(.appCaption)
                        }
                        .foregroundStyle(vaccine.isOverdue ? Color.appDanger : Color.appWarning)
                    }
                    HStack {
                        if !vaccine.veterinarian.isEmpty {
                            Label(vaccine.veterinarian, systemImage: "person")
                                .font(.appCaption).foregroundStyle(.secondary)
                        }
                        if !vaccine.lotNumber.isEmpty {
                            Label(vaccine.lotNumber, systemImage: "number")
                                .font(.appCaption).foregroundStyle(.secondary)
                        }
                        if !vaccine.clinicName.isEmpty {
                            Label(vaccine.clinicName, systemImage: "building.2")
                                .font(.appCaption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.appPrimary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var antiparasiticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            clinicalSectionTitle("ANTIPARASITARIOS", icon: "pills.fill", color: .appSecondary)

            ForEach(pet.antiparasitics.sorted(by: { $0.date > $1.date }), id: \.id) { ap in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ap.productName)
                            .font(.system(.subheadline, design: .rounded).bold())
                        StatusBadge(text: ap.type.rawValue, color: .appSecondary)
                        Spacer()
                        Text(ap.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.appCaption).foregroundStyle(.secondary)
                    }
                    if let nextDate = ap.nextApplicationDate {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.forward.circle.fill").font(.caption2)
                            Text("Próxima: \(nextDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.appCaption)
                        }
                        .foregroundStyle(ap.isOverdue ? Color.appDanger : Color.appWarning)
                    }
                    if !ap.veterinarian.isEmpty {
                        Label(ap.veterinarian, systemImage: "person")
                            .font(.appCaption).foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.appSecondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var medicalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            clinicalSectionTitle("HISTORIAL MÉDICO", icon: "stethoscope", color: .appTertiary)

            ForEach(pet.medicalRecords.sorted(by: { $0.date > $1.date }), id: \.id) { record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.reason)
                            .font(.system(.subheadline, design: .rounded).bold())
                        Spacer()
                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.appCaption).foregroundStyle(.secondary)
                    }
                    if !record.diagnosis.isEmpty {
                        Label("Dx: \(record.diagnosis)", systemImage: "text.document")
                            .font(.appCaption)
                    }
                    if !record.treatment.isEmpty {
                        Label("Tx: \(record.treatment)", systemImage: "cross.vial")
                            .font(.appCaption)
                    }
                    if !record.veterinarian.isEmpty {
                        Label(record.veterinarian, systemImage: "person")
                            .font(.appCaption).foregroundStyle(.secondary)
                    }
                    if !record.clinicName.isEmpty {
                        Label(record.clinicName, systemImage: "building.2")
                            .font(.appCaption).foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.appTertiary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            clinicalSectionTitle("HISTORIAL DE PESO", icon: "scalemass.fill", color: .appBlue)

            ForEach(pet.weightHistory.sorted(by: { $0.date > $1.date }), id: \.id) { entry in
                HStack {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.appCaption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f kg", entry.weight))
                        .font(.system(.subheadline, design: .rounded).bold())
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var qrSection: some View {
        Button {
            showingQR = true
        } label: {
            HStack {
                Image(systemName: "qrcode")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mostrar QR de la Ficha")
                        .font(.appHeadline)
                    Text("Para escanear en la veterinaria")
                        .font(.appCaption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(LinearGradient.appHeader)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var footerSection: some View {
        HStack {
            Image(systemName: "pawprint.fill")
                .font(.caption2)
            Text("Generado por AnimalMbs • \(Date().formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 11, design: .rounded))
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func clinicalSectionTitle(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(.subheadline, design: .rounded).bold())
            .foregroundStyle(color)
    }

    private func infoGrid(_ items: [(String, String)]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(item.1)
                        .font(.system(.subheadline, design: .rounded))
                }
            }
        }
        .padding(12)
        .background(Color.appSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - PDF Generation

    @MainActor
    private func generatePDFForShare() -> URL {
        let renderer = ImageRenderer(content: ClinicalPDFContent(pet: pet))
        renderer.scale = 2.0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HojaClinica_\(pet.name).pdf")

        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(tempURL as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }

        return tempURL
    }
}

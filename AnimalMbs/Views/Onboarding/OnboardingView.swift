import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("pawprint.fill", "Bienvenido a AnimalMbs", "Tu compañero digital para el cuidado de tus mascotas", .appPrimary),
        ("syringe.fill", "Vacunas y Antiparasitarios", "Registra y no olvides nunca una vacuna o desparasitación", .appSecondary),
        ("doc.text.fill", "Hoja Clínica Digital", "Muestra el historial completo con QR en la veterinaria", .appTertiary),
        ("bell.badge.fill", "Recordatorios Inteligentes", "Te avisamos cuando se acerque una vacuna o tratamiento", .appPink),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    onboardingPage(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? pages[currentPage].color : Color.gray.opacity(0.3))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentPage)
                }
            }
            .padding(.bottom, 32)

            // Button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    hasCompletedOnboarding = true
                }
            } label: {
                HStack {
                    Text(currentPage < pages.count - 1 ? "Siguiente" : "¡Comenzar!")
                        .font(.system(.headline, design: .rounded))
                    Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "pawprint.fill")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(pages[currentPage].color)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            if currentPage < pages.count - 1 {
                Button("Saltar") {
                    hasCompletedOnboarding = true
                }
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            } else {
                Color.clear.frame(height: 36)
            }
        }
        .background(Color.appBackground)
    }

    private func onboardingPage(_ page: (icon: String, title: String, subtitle: String, color: Color)) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                // Decorative paws
                ForEach(0..<6, id: \.self) { i in
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: CGFloat([18, 14, 22, 16, 20, 12][i])))
                        .foregroundStyle(page.color.opacity(0.15))
                        .offset(
                            x: CGFloat([-60, 70, -40, 80, -70, 50][i]),
                            y: CGFloat([-50, -30, 40, 50, 20, -60][i])
                        )
                        .rotationEffect(.degrees(Double([-20, 30, -45, 15, -10, 40][i])))
                }

                // Main icon
                ZStack {
                    Circle()
                        .fill(page.color.opacity(0.15))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(page.color.opacity(0.1))
                        .frame(width: 110, height: 110)

                    Image(systemName: page.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(page.color)
                }
            }

            Text(page.title)
                .font(.appTitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(page.subtitle)
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()
            Spacer()
        }
    }
}

import SwiftUI

// MARK: - Adaptive Color Helper
private func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

// MARK: - App Colors
extension Color {
    // Primarios - Tonos cálidos y alegres (ligeramente más brillantes en dark)
    static let appPrimary = adaptiveColor(
        light: UIColor(red: 0.36, green: 0.72, blue: 0.56, alpha: 1),
        dark:  UIColor(red: 0.42, green: 0.82, blue: 0.64, alpha: 1)
    )
    static let appSecondary = adaptiveColor(
        light: UIColor(red: 1.0, green: 0.62, blue: 0.35, alpha: 1),
        dark:  UIColor(red: 1.0, green: 0.70, blue: 0.45, alpha: 1)
    )
    static let appTertiary = adaptiveColor(
        light: UIColor(red: 0.55, green: 0.47, blue: 0.85, alpha: 1),
        dark:  UIColor(red: 0.65, green: 0.57, blue: 0.95, alpha: 1)
    )
    static let appPink = adaptiveColor(
        light: UIColor(red: 0.95, green: 0.45, blue: 0.55, alpha: 1),
        dark:  UIColor(red: 1.0, green: 0.55, blue: 0.62, alpha: 1)
    )
    static let appYellow = adaptiveColor(
        light: UIColor(red: 1.0, green: 0.82, blue: 0.32, alpha: 1),
        dark:  UIColor(red: 1.0, green: 0.87, blue: 0.45, alpha: 1)
    )
    static let appBlue = adaptiveColor(
        light: UIColor(red: 0.35, green: 0.60, blue: 0.95, alpha: 1),
        dark:  UIColor(red: 0.45, green: 0.68, blue: 1.0, alpha: 1)
    )

    // Backgrounds
    static let appBackground = adaptiveColor(
        light: UIColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1),
        dark:  UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    )
    static let appCardBackground = adaptiveColor(
        light: .white,
        dark:  UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1)
    )
    static let appSectionBackground = adaptiveColor(
        light: UIColor(red: 0.93, green: 0.92, blue: 0.89, alpha: 1),
        dark:  UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1)
    )

    // Text
    static let appTextPrimary = adaptiveColor(
        light: UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1),
        dark:  UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    )
    static let appTextSecondary = adaptiveColor(
        light: UIColor(red: 0.40, green: 0.40, blue: 0.43, alpha: 1),
        dark:  UIColor(red: 0.68, green: 0.68, blue: 0.72, alpha: 1)
    )
    static let appTextTertiary = adaptiveColor(
        light: UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1),
        dark:  UIColor(red: 0.52, green: 0.52, blue: 0.56, alpha: 1)
    )

    // Status
    static let appSuccess = adaptiveColor(
        light: UIColor(red: 0.30, green: 0.78, blue: 0.47, alpha: 1),
        dark:  UIColor(red: 0.35, green: 0.85, blue: 0.52, alpha: 1)
    )
    static let appWarning = adaptiveColor(
        light: UIColor(red: 1.0, green: 0.72, blue: 0.27, alpha: 1),
        dark:  UIColor(red: 1.0, green: 0.78, blue: 0.38, alpha: 1)
    )
    static let appDanger = adaptiveColor(
        light: UIColor(red: 0.93, green: 0.35, blue: 0.35, alpha: 1),
        dark:  UIColor(red: 1.0, green: 0.45, blue: 0.42, alpha: 1)
    )

    // Gradientes
    static let gradientStart = adaptiveColor(
        light: UIColor(red: 0.36, green: 0.72, blue: 0.56, alpha: 1),
        dark:  UIColor(red: 0.42, green: 0.82, blue: 0.64, alpha: 1)
    )
    static let gradientEnd = adaptiveColor(
        light: UIColor(red: 0.28, green: 0.58, blue: 0.75, alpha: 1),
        dark:  UIColor(red: 0.35, green: 0.65, blue: 0.85, alpha: 1)
    )
}

// MARK: - App Gradients
extension LinearGradient {
    static let appHeader = LinearGradient(
        colors: [.gradientStart, .gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appWarm = LinearGradient(
        colors: [.appSecondary, .appPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appCool = LinearGradient(
        colors: [.appBlue, .appTertiary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appNature = LinearGradient(
        colors: [.appPrimary, .appYellow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Species Color
extension PetSpecies {
    var themeColor: Color {
        switch self {
        case .dog: return .appPrimary
        case .cat: return .appTertiary
        case .bird: return .appYellow
        case .rabbit: return .appPink
        case .hamster: return .appSecondary
        case .reptile: return .appBlue
        case .other: return .appPrimary
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .dog: return .appHeader
        case .cat: return .appCool
        case .bird: return .appNature
        case .rabbit: return .appWarm
        case .hamster: return LinearGradient(colors: [.appSecondary, .appYellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .reptile: return LinearGradient(colors: [.appBlue, .appPrimary], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .other: return .appHeader
        }
    }
}

// MARK: - Text Styles
extension Font {
    static let appTitle = Font.system(.largeTitle, design: .rounded).bold()
    static let appHeadline = Font.system(.headline, design: .rounded)
    static let appSubheadline = Font.system(.subheadline, design: .rounded)
    static let appBody = Font.system(.body, design: .rounded)
    static let appCaption = Font.system(.caption, design: .rounded)
    static let appCaptionBold = Font.system(.caption, design: .rounded).bold()
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: colorScheme == .dark
                    ? .white.opacity(0.04)
                    : .black.opacity(0.10),
                radius: colorScheme == .dark ? 4 : 6,
                x: 0,
                y: colorScheme == .dark ? 1 : 3
            )
    }
}

struct SectionHeaderStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.appHeadline)
            .foregroundStyle(color)
            .textCase(nil)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func sectionHeader(color: Color = .appPrimary) -> some View {
        modifier(SectionHeaderStyle(color: color))
    }
}

import SwiftUI

// MARK: - Paw Print Background
struct PawPrintBackground: View {
    var opacity: Double = 0.04
    var count: Int = 12

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<count, id: \.self) { i in
                Image(systemName: "pawprint.fill")
                    .font(.system(size: CGFloat.random(in: 14...32)))
                    .foregroundStyle(Color.appPrimary.opacity(opacity))
                    .rotationEffect(.degrees(Double.random(in: -45...45)))
                    .position(
                        x: CGFloat(seededRandom(seed: i * 2, max: Int(geo.size.width))),
                        y: CGFloat(seededRandom(seed: i * 2 + 1, max: Int(geo.size.height)))
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func seededRandom(seed: Int, max: Int) -> Int {
        guard max > 0 else { return 0 }
        return ((seed * 1103515245 + 12345) & 0x7fffffff) % max
    }
}

// MARK: - Pet Avatar
struct PetAvatar: View {
    let pet: Pet
    var size: CGFloat = 60

    var body: some View {
        if let photoData = pet.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(pet.species.themeColor.opacity(0.3), lineWidth: 2)
                )
        } else if let urlStr = pet.photoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        speciesFallback
                        ProgressView()
                            .tint(.white)
                            .controlSize(.regular)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(pet.species.themeColor.opacity(0.3), lineWidth: 2))
                case .failure:
                    speciesFallback
                default:
                    speciesFallback
                }
            }
            .frame(width: size, height: size)
        } else {
            speciesFallback
        }
    }

    private var speciesFallback: some View {
        ZStack {
            Circle()
                .fill(pet.species.gradient)
                .frame(width: size, height: size)

            Image(systemName: pet.species.icon)
                .font(.system(size: size * 0.4))
                .foregroundStyle(.white)
        }
        .shadow(color: pet.species.themeColor.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Info Chip
struct InfoChip: View {
    let icon: String
    let text: String
    var color: Color = .appPrimary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.appCaption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appPrimary)
            }

            Text(title)
                .font(.appHeadline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                    .font(.appHeadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Section Header with Button
struct SectionHeaderView: View {
    let title: String
    let icon: String
    var color: Color = .appPrimary
    var showAdd: Bool = true
    var addAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.appHeadline)
                .foregroundStyle(color)
            Spacer()
            if showAdd, let addAction {
                Button(action: addAction) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
        }
    }
}

// MARK: - Animated Paw Loader
struct PawLoader: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "pawprint.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appPrimary)
                    .opacity(animate ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

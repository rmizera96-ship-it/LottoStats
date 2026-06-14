import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.18, green: 0.55, blue: 0.98)
    static let cardCornerRadius: CGFloat = 22
    static let compactCornerRadius: CGFloat = 16

    static var screenBackground: some View {
        ZStack {
            Color(.systemBackground)

            LinearGradient(
                colors: [
                    accent.opacity(0.075),
                    Color.purple.opacity(0.035),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 360
            )
        }
    }
}

extension LottoGame {
    var visualColor: Color {
        switch self {
        case .lotto:
            return Color(red: 0.12, green: 0.55, blue: 0.98)
        case .miniLotto:
            return Color(red: 0.98, green: 0.58, blue: 0.12)
        case .eurojackpot:
            return Color(red: 0.48, green: 0.32, blue: 0.96)
        }
    }

    var visualGradient: LinearGradient {
        LinearGradient(
            colors: [visualColor, visualColor.opacity(0.68)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var symbolName: String {
        switch self {
        case .lotto:
            return "circle.grid.2x2.fill"
        case .miniLotto:
            return "sparkles"
        case .eurojackpot:
            return "star.circle.fill"
        }
    }

    var ballStyle: NumberBallStyle {
        switch self {
        case .lotto:
            return .lotto
        case .miniLotto:
            return .miniLotto
        case .eurojackpot:
            return .euro
        }
    }
}

enum NumberBallStyle {
    case lotto
    case miniLotto
    case euro
    case plus
    case matched
    case inactive
    case neutral

    var gradient: LinearGradient {
        switch self {
        case .lotto:
            return LinearGradient(
                colors: [Color(red: 0.18, green: 0.61, blue: 1.0), Color(red: 0.08, green: 0.36, blue: 0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .miniLotto:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.72, blue: 0.22), Color(red: 0.94, green: 0.42, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .euro, .plus:
            return LinearGradient(
                colors: [Color(red: 0.61, green: 0.42, blue: 1.0), Color(red: 0.31, green: 0.13, blue: 0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .matched:
            return LinearGradient(
                colors: [Color(red: 0.34, green: 0.83, blue: 0.47), Color(red: 0.07, green: 0.58, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .inactive:
            return LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            return LinearGradient(
                colors: [Color(.tertiarySystemBackground), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var foregroundColor: Color {
        switch self {
        case .inactive, .neutral:
            return .primary
        default:
            return .white
        }
    }

    var borderColor: Color {
        switch self {
        case .inactive, .neutral:
            return Color(.separator).opacity(0.45)
        default:
            return .white.opacity(0.22)
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .inactive, .neutral:
            return 0.04
        default:
            return 0.15
        }
    }
}

struct NumberBall: View {
    let number: Int
    let style: NumberBallStyle
    let size: CGFloat

    init(
        number: Int,
        style: NumberBallStyle = .lotto,
        size: CGFloat = 42
    ) {
        self.number = number
        self.style = style
        self.size = size
    }

    var body: some View {
        Text("\(number)")
            .font(.system(size: max(13, size * 0.4), weight: .bold, design: .rounded))
            .foregroundStyle(style.foregroundColor)
            .frame(width: size, height: size)
            .background(style.gradient)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(style.borderColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(style.shadowOpacity), radius: 5, x: 0, y: 3)
            .accessibilityLabel("Liczba \(number)")
    }
}

struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let tint: Color?
    let cornerRadius: CGFloat
    let content: Content

    init(
        tint: Color? = nil,
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.22 : 0.075),
                radius: colorScheme == .dark ? 10 : 14,
                x: 0,
                y: 6
            )
    }

    private var cardBackground: some View {
        ZStack(alignment: .topTrailing) {
            Color(.secondarySystemBackground)

            if let tint {
                LinearGradient(
                    colors: [
                        tint.opacity(colorScheme == .dark ? 0.14 : 0.08),
                        tint.opacity(colorScheme == .dark ? 0.035 : 0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(tint.opacity(colorScheme == .dark ? 0.055 : 0.035))
                    .frame(width: 118, height: 118)
                    .offset(x: 42, y: -58)

                Circle()
                    .stroke(tint.opacity(colorScheme == .dark ? 0.06 : 0.04), lineWidth: 1)
                    .frame(width: 72, height: 72)
                    .offset(x: 6, y: -32)
            }
        }
    }

    private var borderColor: Color {
        if let tint {
            return tint.opacity(colorScheme == .dark ? 0.24 : 0.13)
        }

        return Color(.separator).opacity(colorScheme == .dark ? 0.30 : 0.16)
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = AppTheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: tint.opacity(0.28), radius: 9, x: 0, y: 5)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = AppTheme.accent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.17), lineWidth: 1)
                    }
                    .shadow(color: tint.opacity(0.20), radius: 6, x: 0, y: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .layoutPriority(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
        }
    }
}

struct CardHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color = AppTheme.accent,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.22), radius: 7, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .layoutPriority(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color = AppTheme.accent
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            icon: icon,
            tint: tint
        ) {
            EmptyView()
        }
    }
}

struct EmptyStateArtwork: View {
    let icon: String
    var tint: Color = AppTheme.accent
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.075))
                .frame(width: size, height: size)

            Circle()
                .stroke(tint.opacity(0.13), lineWidth: 1)
                .frame(width: size * 0.76, height: size * 0.76)

            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: size * 0.26, height: size * 0.26)
                .offset(x: size * 0.34, y: -size * 0.29)

            Circle()
                .fill(tint.opacity(0.09))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.34, y: size * 0.28)

            Image(systemName: icon)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size * 0.56, height: size * 0.56)
                .background(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
                .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 5)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct EmptyStateCard<ActionLabel: View>: View {
    let title: String
    let message: String
    let icon: String
    let tint: Color
    let actionLabel: ActionLabel?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        icon: String,
        tint: Color = AppTheme.accent,
        action: (() -> Void)? = nil,
        @ViewBuilder actionLabel: () -> ActionLabel
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.tint = tint
        self.action = action
        self.actionLabel = actionLabel()
    }

    var body: some View {
        AppCard(tint: tint) {
            VStack(spacing: 14) {
                EmptyStateArtwork(icon: icon, tint: tint, size: 94)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let action, let actionLabel {
                    Button(action: action) {
                        actionLabel
                    }
                    .buttonStyle(PrimaryActionButtonStyle(tint: tint))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }
}

extension EmptyStateCard where ActionLabel == EmptyView {
    init(
        title: String,
        message: String,
        icon: String,
        tint: Color = AppTheme.accent
    ) {
        self.init(
            title: title,
            message: message,
            icon: icon,
            tint: tint,
            action: nil
        ) {
            EmptyView()
        }
    }
}

struct CelebrationBadge: View {
    let text: String
    var tint: Color = .green

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(tint.opacity(0.16), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
                .offset(x: 4, y: -4)
        }
    }
}

struct GameBadge: View {
    let game: LottoGame

    var body: some View {
        Label(game.displayName, systemImage: game.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(game.visualColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(game.visualColor.opacity(0.12))
            .clipShape(Capsule())
    }
}


struct GameSelector: View {
    let games: [LottoGame]
    @Binding var selection: LottoGame

    var body: some View {
        HStack(spacing: 7) {
            ForEach(games) { game in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selection = game
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: game.symbolName)
                            .font(.caption2.weight(.bold))

                        Text(game.displayName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(selection == game ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        if selection == game {
                            game.visualGradient
                        } else {
                            Color(.tertiarySystemFill)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(
                                selection == game
                                    ? Color.white.opacity(0.18)
                                    : Color(.separator).opacity(0.12),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: selection == game
                            ? game.visualColor.opacity(0.24)
                            : .clear,
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wybierz grę \(game.displayName)")
            }
        }
        .padding(5)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.22), value: selection)
    }
}

struct IconCircleButton: View {
    let systemImage: String
    var tint: Color = AppTheme.accent
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                }
            }
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.13))
            .foregroundStyle(tint)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.accent
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [tint, tint.opacity(0.70)]
                        : [Color.gray.opacity(0.45), Color.gray.opacity(0.30)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.16 : 0), lineWidth: 1)
            }
            .shadow(
                color: isEnabled ? tint.opacity(0.25) : .clear,
                radius: configuration.isPressed ? 3 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        AppCard(tint: AppTheme.accent) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

enum AppFormatters {
    static let polishLongDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    static let polishShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    static let polishDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()

    static func currency(_ value: Double, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .currency
        formatter.currencyCode = "PLN"
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) zł"
    }
}

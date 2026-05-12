import SwiftUI

enum NumberBallStyle {
    case lotto
    case plus
    case matched
    case inactive
    case neutral
    
    var backgroundColor: Color {
        switch self {
        case .lotto:
            return Color.blue.opacity(0.15)
        case .plus:
            return Color.purple.opacity(0.15)
        case .matched:
            return Color.green.opacity(0.3)
        case .inactive:
            return Color.gray.opacity(0.15)
        case .neutral:
            return Color(.tertiarySystemBackground)
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
            .font(.headline)
            .fontWeight(.semibold)
            .frame(width: size, height: size)
            .background(style.backgroundColor)
            .clipShape(Circle())
    }
}

struct AppCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        AppCard {
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

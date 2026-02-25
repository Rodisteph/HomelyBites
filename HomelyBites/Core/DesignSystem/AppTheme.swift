import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design System Colors (Using Color Assets for Dark Mode Support)
enum AppColors {
    // Primary palette from Color Assets
    static let primary      = Color("Primary")        // Terracotta #C4623A
    static let primaryDark  = Color("PrimaryDark")    // Darker terracotta #9B4A2A
    static let primaryLight = Color("PrimaryLight")   // Light terracotta #F2D5C8
    static let charcoal     = Color("Charcoal")       // Deep charcoal #2C2825
    static let cream        = Color("Cream")          // Soft cream #FAF7F2
    static let muted        = Color("Muted")          // Muted gray #A09890
    static let border       = Color("Border")         // Border gray #EDE8E2
    static let sage         = Color("Sage")           // Sage green #7A8C6E

    // Semantic colors
    static let background   = Color("Cream")
    static let surface      = Color.white
    static let textPrimary  = Color("Charcoal")
    static let textSecondary = Color("Muted")

    // Status colors from Color Assets
    static let success = Color("Success")             // Green #4A7C59
    static let danger  = Color("Danger")              // Red #B04040
    static let warning = Color("Primary")             // Reuse terracotta for warnings
    static let info    = Color("Info")                // Blue #3A6B9B

    // Legacy aliases (kept for backward compatibility)
    static let terracotta      = primary
    static let terracottaLight = primaryLight
    static let terracottaDark  = primaryDark
    static let creamDark       = border
    static let secondary       = sage
}

// MARK: - Typography Extensions
extension Font {
    // Cormorant Garamond (Display/Headings)
    static func cormorantDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .semibold:
            fontName = "CormorantGaramond-SemiBold"
        case .medium:
            fontName = "CormorantGaramond-Medium"
        default:
            fontName = "CormorantGaramond-Regular"
        }
        return .custom(fontName, size: size)
    }

    static func cormorantItalic(_ size: CGFloat) -> Font {
        return .custom("CormorantGaramond-Italic", size: size)
    }

    // DM Sans (Body/UI)
    static func dmSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .bold:
            fontName = "DMSans-Bold"
        case .semibold:
            fontName = "DMSans-SemiBold"
        case .medium:
            fontName = "DMSans-Medium"
        default:
            fontName = "DMSans-Regular"
        }
        return .custom(fontName, size: size)
    }

    // Semantic font styles
    static let displayLarge = cormorantDisplay(48, weight: .semibold)
    static let displayMedium = cormorantDisplay(36, weight: .semibold)
    static let displaySmall = cormorantDisplay(28, weight: .medium)

    static let headlineLarge = dmSans(24, weight: .semibold)
    static let headlineMedium = dmSans(20, weight: .semibold)
    static let headlineSmall = dmSans(18, weight: .semibold)

    static let bodyLarge = dmSans(16, weight: .regular)
    static let bodyMedium = dmSans(14, weight: .regular)
    static let bodySmall = dmSans(12, weight: .regular)

    static let labelLarge = dmSans(14, weight: .medium)
    static let labelMedium = dmSans(12, weight: .medium)
    static let labelSmall = dmSans(10, weight: .medium)
}

// MARK: - Metrics
enum AppMetrics {
    static let cardCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 20
    static let verticalSpacing: CGFloat = 16
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmSans(16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .fill(isLoading ? AppColors.terracotta.opacity(0.6) : AppColors.terracotta)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmSans(16, weight: .medium))
            .foregroundStyle(AppColors.terracotta)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .fill(AppColors.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .stroke(AppColors.terracotta, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    enum BadgeType {
        case pending, confirmed, completed, cancelled

        var color: Color {
            switch self {
            case .pending: return AppColors.warning
            case .confirmed: return Color(hex: "4A90E2")
            case .completed: return AppColors.success
            case .cancelled: return AppColors.danger
            }
        }

        var label: String {
            switch self {
            case .pending: return "En attente"
            case .confirmed: return "Confirmé"
            case .completed: return "Terminé"
            case .cancelled: return "Annulé"
            }
        }
    }

    let type: BadgeType

    var body: some View {
        Text(type.label)
            .font(.dmSans(12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(type.color)
            )
    }
}

// MARK: - Card Modifier
struct AppCardModifier: ViewModifier {
    var shadowEnabled: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .stroke(AppColors.textSecondary.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: shadowEnabled ? AppColors.charcoal.opacity(0.08) : .clear,
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Text Field Modifier
struct AppTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.dmSans(16, weight: .regular))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Brand Logo View
struct BrandLogoView: View {
    var size: CGFloat = 100

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = UIImage(named: "HomelyBitesLogo") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackMark
            }
            #else
            fallbackMark
            #endif
        }
        .frame(width: size, height: size)
        .accessibilityLabel("HomelyBites")
    }

    private var fallbackMark: some View {
        ZStack {
            Circle()
                .fill(AppColors.terracottaLight.opacity(0.2))

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(AppColors.terracotta)
        }
    }
}

// MARK: - View Extensions
extension View {
    func appCard(shadowEnabled: Bool = true) -> some View {
        modifier(AppCardModifier(shadowEnabled: shadowEnabled))
    }

    func appTextFieldStyle() -> some View {
        modifier(AppTextFieldModifier())
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)

        let red: Double
        let green: Double
        let blue: Double
        switch trimmed.count {
        case 6:
            red = Double((int >> 16) & 0xFF) / 255.0
            green = Double((int >> 8) & 0xFF) / 255.0
            blue = Double(int & 0xFF) / 255.0
        default:
            red = 0
            green = 0
            blue = 0
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

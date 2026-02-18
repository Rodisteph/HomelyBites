import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppColors {
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let success = Color(hex: "2E7D32")
    static let warning = Color(hex: "ED6C02")
    static let danger = Color(hex: "C62828")
}

enum AppMetrics {
    static let cardCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
}

struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .fill(isLoading ? AppColors.primary.opacity(0.65) : AppColors.primary)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .stroke(AppColors.textSecondary.opacity(0.08), lineWidth: 1)
            )
    }
}

struct AppTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                    .stroke(AppColors.textSecondary.opacity(0.12), lineWidth: 1)
            )
    }
}

struct BrandLogoView: View {
    var size: CGFloat = 84

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
        // TODO: Replace this placeholder mark with the final brand asset when provided.
        return ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.12))

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(AppColors.primary)
        }
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }

    func appTextFieldStyle() -> some View {
        modifier(AppTextFieldModifier())
    }
}

private extension Color {
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

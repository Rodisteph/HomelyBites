import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Single source of truth for HomelyBites design tokens

enum HBTheme {

    // MARK: - Colors

    enum Colors {
        // Core
        static let primary     = Color(red: 200/255, green: 74/255, blue: 58/255)   // #C84A3A Terracotta
        static let primaryDark = Color(red: 160/255, green: 58/255, blue: 46/255)    // #A03A2E
        static let primaryLight = Color(red: 220/255, green: 111/255, blue: 97/255)  // #DC6F61

        // Backgrounds
        static let background  = Color(red: 248/255, green: 245/255, blue: 241/255) // #F8F5F1 Cream
        static let surface     = Color.white
        static let skeleton    = Color(red: 237/255, green: 233/255, blue: 227/255)

        // Text
        static let text        = Color(red: 27/255, green: 27/255, blue: 31/255)    // #1B1B1F Charcoal
        static let textSecondary = Color(red: 107/255, green: 111/255, blue: 118/255) // #6B6F76

        // Border
        static let border      = Color(red: 230/255, green: 225/255, blue: 219/255) // #E6E1DB

        // Accent
        static let sage        = Color(red: 122/255, green: 140/255, blue: 110/255) // #7A8C6E

        // Semantic
        static let success     = Color(red: 74/255, green: 124/255, blue: 89/255)   // #4A7C59
        static let danger      = Color(red: 176/255, green: 64/255, blue: 64/255)   // #B04040
        static let info        = Color(red: 58/255, green: 107/255, blue: 155/255)  // #3A6B9B
        static let warning     = primary
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat  = 8
        static let s: CGFloat   = 12
        static let m: CGFloat   = 16
        static let l: CGFloat   = 20
        static let xl: CGFloat  = 28
        static let screen: CGFloat = 20
    }

    // MARK: - Radius

    enum Radius {
        static let card: CGFloat    = 16
        static let button: CGFloat  = 12
        static let input: CGFloat   = 12
        static let chip: CGFloat    = 999
        static let thumb: CGFloat   = 12
    }

    // MARK: - Shadows

    enum Shadow {
        static let softColor    = Colors.text.opacity(0.08)
        static let softRadius: CGFloat   = 10
        static let softY: CGFloat        = 4

        static let strongColor  = Colors.text.opacity(0.18)
        static let strongRadius: CGFloat = 16
        static let strongY: CGFloat      = 8
    }

    // MARK: - Typography

    enum Font {
        static func display(_ size: CGFloat = 36) -> SwiftUI.Font {
            cormorant(size: size, weight: .semibold, style: .largeTitle)
        }

        static func title(_ size: CGFloat = 24) -> SwiftUI.Font {
            cormorant(size: size, weight: .semibold, style: .title2)
        }

        static func body(_ size: CGFloat = 16, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            dmSans(size: size, weight: weight, style: .body)
        }

        static func label(_ size: CGFloat = 13, weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            dmSans(size: size, weight: weight, style: .caption)
        }

        // Presets
        static let screenTitle = display(34)
        static let sectionTitle = title(28)
        static let cardTitle = title(22)
        static let price = body(20, weight: .bold)
        static let caption = label(13, weight: .medium)

        // MARK: Private

        private static func cormorant(size: CGFloat, weight: SwiftUI.Font.Weight, style: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
            let candidates: [String]
            switch weight {
            case .semibold, .bold:
                candidates = ["CormorantGaramond-SemiBold", "Cormorant Garamond SemiBold"]
            case .medium:
                candidates = ["CormorantGaramond-Medium", "Cormorant Garamond Medium"]
            default:
                candidates = ["CormorantGaramond-Regular", "Cormorant Garamond"]
            }
            return resolved(candidates: candidates, size: size, style: style,
                            fallback: .system(size: size, weight: weight, design: .serif))
        }

        private static func dmSans(size: CGFloat, weight: SwiftUI.Font.Weight, style: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
            let candidates: [String]
            switch weight {
            case .bold:
                candidates = ["DMSans-Bold", "DM Sans Bold"]
            case .semibold:
                candidates = ["DMSans-SemiBold", "DM Sans SemiBold"]
            case .medium:
                candidates = ["DMSans-Medium", "DM Sans Medium"]
            default:
                candidates = ["DMSans-Regular", "DM Sans Regular"]
            }
            return resolved(candidates: candidates, size: size, style: style,
                            fallback: .system(size: size, weight: weight, design: .rounded))
        }

        private static func resolved(candidates: [String], size: CGFloat, style: SwiftUI.Font.TextStyle, fallback: SwiftUI.Font) -> SwiftUI.Font {
            #if canImport(UIKit)
            if let name = candidates.first(where: { UIFont(name: $0, size: size) != nil }) {
                return .custom(name, size: size, relativeTo: style)
            }
            #endif
            return fallback
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let r, g, b: Double
        if trimmed.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

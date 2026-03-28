import SwiftUI

// MARK: - Shadow Preset

enum HBShadowPreset {
    case soft, strong
}

// MARK: - View Modifiers

extension View {

    /// Card container styling: padding + white bg + border + shadow
    func hbCard() -> some View {
        modifier(HBCardModifier())
    }

    /// Shadow only
    func hbShadow(_ preset: HBShadowPreset = .soft) -> some View {
        modifier(HBShadowModifier(preset: preset))
    }

    /// Section title styling (Cormorant 24, charcoal)
    func hbTitle() -> some View {
        self
            .font(HBTheme.Font.title())
            .foregroundStyle(HBTheme.Colors.text)
    }

    /// Body text styling
    func hbBody() -> some View {
        self
            .font(HBTheme.Font.body())
            .foregroundStyle(HBTheme.Colors.textSecondary)
    }

    /// Chip / pill toggle styling
    func hbChipStyle(selected: Bool = false) -> some View {
        modifier(HBChipModifier(selected: selected))
    }

    /// Cream background ignoring safe area
    func hbBackground() -> some View {
        background(HBTheme.Colors.background.ignoresSafeArea())
    }

    /// Styled text field
    func hbInputStyle() -> some View {
        self
            .font(HBTheme.Font.body(15))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: HBTheme.Radius.input, style: .continuous)
                    .fill(HBTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HBTheme.Radius.input, style: .continuous)
                    .stroke(HBTheme.Colors.border, lineWidth: 1)
            )
    }

    /// Navigation title with cream toolbar
    func hbNavTitle(_ title: String, displayMode: NavigationBarItem.TitleDisplayMode = .inline) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .toolbarBackground(HBTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Private Modifiers

private struct HBCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(HBTheme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: HBTheme.Radius.card, style: .continuous)
                    .fill(HBTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HBTheme.Radius.card, style: .continuous)
                    .stroke(HBTheme.Colors.border, lineWidth: 1)
            )
            .shadow(color: HBTheme.Shadow.softColor, radius: HBTheme.Shadow.softRadius, x: 0, y: HBTheme.Shadow.softY)
    }
}

private struct HBShadowModifier: ViewModifier {
    let preset: HBShadowPreset

    func body(content: Content) -> some View {
        switch preset {
        case .soft:
            content.shadow(color: HBTheme.Shadow.softColor, radius: HBTheme.Shadow.softRadius, x: 0, y: HBTheme.Shadow.softY)
        case .strong:
            content.shadow(color: HBTheme.Shadow.strongColor, radius: HBTheme.Shadow.strongRadius, x: 0, y: HBTheme.Shadow.strongY)
        }
    }
}

private struct HBChipModifier: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .font(HBTheme.Font.label(12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? HBTheme.Colors.primary : HBTheme.Colors.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selected ? HBTheme.Colors.primary : HBTheme.Colors.border, lineWidth: 1)
            )
            .foregroundStyle(selected ? Color.white : HBTheme.Colors.textSecondary)
    }
}

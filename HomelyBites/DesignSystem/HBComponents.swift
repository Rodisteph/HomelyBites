import SwiftUI

// MARK: - Card

struct CardContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HBTheme.Spacing.m) {
            content
        }
        .hbCard()
    }
}

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(title)
                        .font(HBTheme.Font.body(16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: HBTheme.Radius.button, style: .continuous)
                    .fill(HBTheme.Colors.primary)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? 0.7 : 1)
        .scaleEffect((isDisabled || isLoading) ? 1 : 1) // preserve layout
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(HBTheme.Font.body(16, weight: .medium))
            }
            .foregroundStyle(HBTheme.Colors.text)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: HBTheme.Radius.button, style: .continuous)
                    .fill(HBTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HBTheme.Radius.button, style: .continuous)
                    .stroke(HBTheme.Colors.border, lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
    }
}

// MARK: - Badge

struct Badge: View {
    enum Kind {
        case success, warning, danger, info, neutral

        var foreground: Color {
            switch self {
            case .success: return HBTheme.Colors.success
            case .warning: return HBTheme.Colors.warning
            case .danger:  return HBTheme.Colors.danger
            case .info:    return HBTheme.Colors.info
            case .neutral: return HBTheme.Colors.textSecondary
            }
        }
    }

    let label: String
    var kind: Kind = .neutral

    var body: some View {
        Text(label)
            .font(HBTheme.Font.label(12, weight: .semibold))
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(kind.foreground.opacity(0.14)))
    }
}

// MARK: - Order Row

struct OrderRow: View {
    let order: Order
    var onConfirm: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: HBTheme.Spacing.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: HBTheme.Spacing.xs) {
                    Text("Commande #\(order.id?.prefix(8) ?? "--------")")
                        .font(HBTheme.Font.title(20))
                        .foregroundStyle(HBTheme.Colors.text)
                    Text("Portions : \(order.portions)")
                        .font(HBTheme.Font.label())
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
                Spacer()
                Text(order.amountCents.asEuro())
                    .font(HBTheme.Font.body(20, weight: .bold))
                    .foregroundStyle(HBTheme.Colors.primary)
            }

            HStack(spacing: HBTheme.Spacing.s) {
                Badge(label: order.status.displayTitle, kind: statusKind)
                Badge(label: order.paymentStatus.displayTitle, kind: paymentKind)
            }

            if order.status == .pending,
               let onConfirm,
               let onReject {
                HStack(spacing: HBTheme.Spacing.s) {
                    PrimaryButton(title: "Confirmer", action: onConfirm)
                    SecondaryButton(title: "Rejeter", action: onReject)
                }
            }
        }
        .hbCard()
    }

    private var statusKind: Badge.Kind {
        switch order.status {
        case .pending: return .warning
        case .confirmed: return .info
        case .cancelled, .rejected: return .danger
        }
    }

    private var paymentKind: Badge.Kind {
        switch order.paymentStatus {
        case .requires_payment: return .warning
        case .paid: return .success
        case .failed: return .danger
        case .refunded: return .neutral
        }
    }
}

// MARK: - Brand Logo

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
                .fill(HBTheme.Colors.primaryLight.opacity(0.2))
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(HBTheme.Colors.primary)
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Rechercher"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(HBTheme.Colors.textSecondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(HBTheme.Font.body(15))
                .foregroundStyle(HBTheme.Colors.text)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
            }
        }
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
}

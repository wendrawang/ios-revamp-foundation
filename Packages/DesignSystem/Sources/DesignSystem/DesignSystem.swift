import SwiftUI

public enum DSColor {
    public static let accent = Color.red
    public static let accentForeground = Color.white
    public static let background = Color(uiColor: .systemBackground)
    public static let surface = Color(uiColor: .secondarySystemBackground)
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let blockerScrim = Color.black.opacity(0.48)
}

public enum DSSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

public struct DSPrimaryButton: View {
    private let title: String
    private let accessibilityIdentifier: String?
    private let action: () -> Void

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(title: String, accessibilityIdentifier: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(DSColor.accentForeground)
                .background(DSColor.accent, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

public struct DSFeatureCard<Content: View>: View {
    private let title: String
    private let content: () -> Content

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(title).font(.title3.bold())
            content()
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

public struct DSBottomSheetScaffold: View {
    private let title: String
    private let message: String
    private let primaryTitle: String
    private let primaryAccessibilityIdentifier: String?
    private let onPrimary: () -> Void
    private let onDismiss: () -> Void

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(
        title: String,
        message: String,
        primaryTitle: String,
        primaryAccessibilityIdentifier: String? = nil,
        onPrimary: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryAccessibilityIdentifier = primaryAccessibilityIdentifier
        self.onPrimary = onPrimary
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Capsule().fill(Color.secondary).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                Text(title).font(.title3.bold())
                Text(message).font(.body).foregroundStyle(.secondary)
                DSPrimaryButton(
                    title: primaryTitle,
                    accessibilityIdentifier: primaryAccessibilityIdentifier,
                    action: onPrimary
                )
            }
            .padding(DSSpacing.lg)
            .background(DSColor.background, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.isModal)
    }
}

public struct DSBlockerView: View {
    private let icon: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let accessibilityIdentifier: String
    private let action: (() -> Void)?

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        accessibilityIdentifier: String,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        ZStack {
            DSColor.blockerScrim.ignoresSafeArea()
            VStack(spacing: DSSpacing.md) {
                Image(systemName: icon).font(.largeTitle).foregroundStyle(DSColor.accent)
                Text(title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let actionTitle, let action {
                    DSPrimaryButton(title: actionTitle, action: action)
                }
            }
            .padding(DSSpacing.lg)
            .background(DSColor.background, in: RoundedRectangle(cornerRadius: 20))
            .padding(DSSpacing.lg)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(.isModal)
    }
}

public struct DSTabItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let systemImage: String
    public let accessibilityIdentifier: String
    public let isElevated: Bool

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(
        id: ID,
        title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        isElevated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.isElevated = isElevated
    }
}

public struct DSCustomTabBar<ID: Hashable>: View {
    private let items: [DSTabItem<ID>]
    private let selection: ID
    private let onSelect: (ID) -> Void

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(items: [DSTabItem<ID>], selection: ID, onSelect: @escaping (ID) -> Void) {
        self.items = items
        self.selection = selection
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.systemImage)
                            .font(item.isElevated ? .title2.bold() : .title3)
                            .frame(width: item.isElevated ? 58 : 44, height: item.isElevated ? 58 : 44)
                            .foregroundStyle(item.isElevated ? DSColor.accentForeground : color(for: item))
                            .background(item.isElevated ? DSColor.accent : Color.clear, in: Circle())
                            .shadow(color: item.isElevated ? .black.opacity(0.18) : .clear, radius: 7, y: 4)
                        Text(item.title)
                            .font(.caption2)
                            .foregroundStyle(color(for: item))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .offset(y: item.isElevated ? -14 : 0)
                }
                .accessibilityIdentifier(item.accessibilityIdentifier)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item.id ? .isSelected : [])
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.top, DSSpacing.sm)
        .background(.regularMaterial)
    }

    // Memilih warna visual tab berdasarkan selected state.
    private func color(for item: DSTabItem<ID>) -> Color {
        selection == item.id ? DSColor.accent : DSColor.textSecondary
    }
}

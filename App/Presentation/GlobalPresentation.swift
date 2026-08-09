import Combine
import DesignSystem
import SwiftUI

struct GlobalPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let primaryButtonTitle: String
}

@MainActor
final class GlobalPresentationController: ObservableObject {
    @Published private(set) var current: GlobalPresentation?
    private var queue: [GlobalPresentation] = []

    // Menampilkan presentasi global atau memasukkannya ke antrean.
    func present(_ presentation: GlobalPresentation) {
        guard current == nil else {
            queue.append(presentation)
            return
        }
        current = presentation
    }

    // Menutup presentasi aktif dan menampilkan antrean berikutnya bila ada.
    func dismiss() {
        current = queue.isEmpty ? nil : queue.removeFirst()
    }
}

struct GlobalPresentationHost: View {
    @ObservedObject var controller: GlobalPresentationController

    var body: some View {
        if let presentation = controller.current {
            DSBottomSheetScaffold(
                title: presentation.title,
                message: presentation.message,
                primaryTitle: presentation.primaryButtonTitle,
                onPrimary: { controller.dismiss() },
                onDismiss: { controller.dismiss() }
            )
        }
    }
}

enum GlobalBlocker: Hashable, Sendable {
    case connectivity
    case maintenance
    case forceUpdate
    case securityRestriction

    var priority: Int {
        switch self {
        case .connectivity: 100
        case .maintenance: 200
        case .forceUpdate, .securityRestriction: 300
        }
    }
}

@MainActor
final class GlobalBlockerController: ObservableObject {
    @Published private(set) var activeBlockers: Set<GlobalBlocker> = []

    var current: GlobalBlocker? {
        activeBlockers.max(by: { $0.priority < $1.priority })
    }

    var isBlocking: Bool { current != nil }

    // Mengaktifkan blocker agar host global menampilkannya.
    func show(_ blocker: GlobalBlocker) { activeBlockers.insert(blocker) }
    // Menghapus blocker tanpa mengubah navigation state.
    func hide(_ blocker: GlobalBlocker) { activeBlockers.remove(blocker) }

    // Mengubah status blocker connectivity untuk kebutuhan sample dan test.
    func toggleConnectivity() {
        if activeBlockers.contains(.connectivity) {
            hide(.connectivity)
        } else {
            show(.connectivity)
        }
    }
}

struct GlobalBlockerHost: View {
    @ObservedObject var controller: GlobalBlockerController

    @ViewBuilder var body: some View {
        if let blocker = controller.current {
            switch blocker {
            case .connectivity:
                DSBlockerView(
                    icon: "wifi.slash",
                    title: "No internet connection",
                    message: "Your current journey is preserved while connectivity recovers.",
                    actionTitle: "Connection restored",
                    accessibilityIdentifier: AppAccessibilityID.connectivityBlocker,
                    action: { controller.hide(.connectivity) }
                )
            case .maintenance:
                DSBlockerView(
                    icon: "wrench.and.screwdriver",
                    title: "Maintenance",
                    message: "Banking services are temporarily unavailable.",
                    accessibilityIdentifier: AppAccessibilityID.maintenanceBlocker
                )
            case .forceUpdate:
                DSBlockerView(
                    icon: "arrow.down.app",
                    title: "Update required",
                    message: "Install the latest secure version to continue.",
                    accessibilityIdentifier: AppAccessibilityID.forceUpdateBlocker
                )
            case .securityRestriction:
                DSBlockerView(
                    icon: "exclamationmark.shield",
                    title: "Security restriction",
                    message: "The application cannot continue on this device.",
                    accessibilityIdentifier: AppAccessibilityID.securityBlocker
                )
            }
        }
    }
}

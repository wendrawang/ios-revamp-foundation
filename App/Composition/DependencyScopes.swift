import CoreAnalytics
import CoreFeatureFlags
import CoreLogging
import CoreNetworking
import CoreSecurity
import CoreSession
import Foundation
import ScanFeature
import TransferFeature
import WealthFeature

@MainActor
final class AppContainer {
    let logger: any AppLogging
    let analytics: any AnalyticsTracking
    let featureFlags: InMemoryFeatureFlags
    let credentialManager: SessionCredentialManager
    let presentationController: GlobalPresentationController
    let blockerController: GlobalBlockerController
    let lifecycleController: AppLifecycleController
    let securityMonitor: any SecurityMonitoring
    let deepLinkRegistry: DeepLinkRegistry

    init(isUITesting: Bool = false) {
        let logger = InMemoryLogger()
        let analytics = InMemoryAnalytics()
        let flags = InMemoryFeatureFlags(
            enabled: [.wealthEntryEnabled, .webSampleEnabled],
            logger: logger
        )
        self.logger = logger
        self.analytics = analytics
        featureFlags = flags
        credentialManager = SessionCredentialManager(vault: InMemoryCredentialVault(), logger: logger)
        presentationController = GlobalPresentationController()
        blockerController = GlobalBlockerController()
        lifecycleController = AppLifecycleController(analytics: analytics)
        securityMonitor = NoOpSecurityMonitor()
        deepLinkRegistry = DeepLinkRegistryFactory.make(featureFlags: flags)
    }
}

@MainActor
final class SessionScope {
    let credentials: SessionCredentials
    let transferService: any TransferServicing
    let wealthService: any WealthServicing
    private let credentialManager: SessionCredentialManager
    private(set) var cache: [String: String] = [:]
    private var tasks: [Task<Void, Never>] = []
    private(set) var isInvalidated = false

    init(
        credentials: SessionCredentials,
        credentialManager: SessionCredentialManager,
        transferService: any TransferServicing,
        wealthService: any WealthServicing
    ) {
        self.credentials = credentials
        self.credentialManager = credentialManager
        self.transferService = transferService
        self.wealthService = wealthService
    }

    func retainBackgroundTask(_ task: Task<Void, Never>) {
        tasks.append(task)
    }

    func invalidate() async {
        guard !isInvalidated else { return }
        isInvalidated = true
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        cache.removeAll()
        try? await credentialManager.invalidate(reason: .logout)
    }
}

@MainActor
final class AuthenticatedFlowScope {
    let scanCamera: SampleCameraController
    let scanViewModel: ScanViewModel
    private(set) var isDeactivated = false

    init() {
        let camera = SampleCameraController()
        scanCamera = camera
        scanViewModel = ScanViewModel(camera: camera)
    }

    func deactivate() {
        guard !isDeactivated else { return }
        isDeactivated = true
        scanViewModel.setOperational(false)
    }
}

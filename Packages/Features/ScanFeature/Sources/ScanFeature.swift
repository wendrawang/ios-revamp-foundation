import Combine
import DesignSystem
import SwiftUI

@MainActor
public protocol CameraControlling: AnyObject {
    var isRunning: Bool { get }
    func start()
    func stop()
}

@MainActor
public final class SampleCameraController: CameraControlling, ObservableObject {
    @Published public private(set) var isRunning = false
    public private(set) var startCount = 0
    public private(set) var stopCount = 0

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        startCount += 1
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        stopCount += 1
    }
}

@MainActor
public final class ScanViewModel: ObservableObject {
    @Published public private(set) var isCameraRunning = false
    private let camera: any CameraControlling

    public init(camera: any CameraControlling) {
        self.camera = camera
    }

    public func setOperational(_ operational: Bool) {
        if operational {
            camera.start()
        } else {
            camera.stop()
        }
        isCameraRunning = camera.isRunning
    }

    deinit {
        MainActor.assumeIsolated { camera.stop() }
    }
}

public struct ScanRootView: View {
    @ObservedObject private var viewModel: ScanViewModel
    private let isOperational: Bool

    public init(viewModel: ScanViewModel, isOperational: Bool) {
        self.viewModel = viewModel
        self.isOperational = isOperational
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black)
                .overlay {
                    VStack(spacing: DSSpacing.md) {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 72)).foregroundStyle(.white)
                        Text(viewModel.isCameraRunning ? "Camera resource active" : "Camera resource stopped")
                            .foregroundStyle(.white)
                    }
                }
                .aspectRatio(0.82, contentMode: .fit)
            Text("The sample uses a camera abstraction. Production capture can replace it behind the same lifetime contract.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .navigationTitle("Scan")
        .onAppear { viewModel.setOperational(isOperational) }
        .onChange(of: isOperational) { viewModel.setOperational($0) }
        .onDisappear { viewModel.setOperational(false) }
    }
}


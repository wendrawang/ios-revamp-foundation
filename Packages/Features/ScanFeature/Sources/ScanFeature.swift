import Combine
import DesignSystem
import SwiftUI

@MainActor
public protocol CameraControlling: AnyObject {
    var isRunning: Bool { get }
    // Memulai resource atau flow yang dimiliki tipe ini.
    func start()
    // Menghentikan resource agar tidak melewati lifetime pemiliknya.
    func stop()
}

@MainActor
public final class SampleCameraController: CameraControlling, ObservableObject {
    @Published public private(set) var isRunning = false
    public private(set) var startCount = 0
    public private(set) var stopCount = 0

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}

    // Memulai resource atau flow yang dimiliki tipe ini.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        startCount += 1
    }

    // Menghentikan resource agar tidak melewati lifetime pemiliknya.
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

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(camera: any CameraControlling) {
        self.camera = camera
    }

    // Menyalakan atau mematikan camera sesuai aktivitas tab dan lifecycle.
    public func setOperational(_ isOperational: Bool) {
        if isOperational {
            camera.start()
        } else {
            camera.stop()
        }
        isCameraRunning = camera.isRunning
    }

    // Menghentikan resource yang masih dimiliki saat instance dilepas.
    deinit {
        MainActor.assumeIsolated { camera.stop() }
    }
}

public struct ScanRootView: View {
    @ObservedObject private var viewModel: ScanViewModel
    private let isOperational: Bool

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(viewModel: ScanViewModel, isOperational: Bool) {
        self.viewModel = viewModel
        self.isOperational = isOperational
    }

    public var body: some View {
        VStack(spacing: DSSpacing.large) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black)
                .overlay {
                    VStack(spacing: DSSpacing.medium) {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 72)).foregroundStyle(.white)
                        Text(viewModel.isCameraRunning ? "Camera resource active" : "Camera resource stopped")
                            .foregroundStyle(.white)
                    }
                }
                .aspectRatio(0.82, contentMode: .fit)
            Text(
                "The sample uses a camera abstraction. Production capture can replace it behind the same lifetime contract."
            )
            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(DSSpacing.large)
        .navigationTitle("Scan")
        .onAppear { viewModel.setOperational(isOperational) }
        .onChange(of: isOperational) { updatedState in
            viewModel.setOperational(updatedState)
        }
        .onDisappear { viewModel.setOperational(false) }
    }
}

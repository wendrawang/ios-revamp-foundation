import ScanFeature
import Testing

private final class WeakReference<Object: AnyObject> {
    weak var value: Object?
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(_ value: Object?) { self.value = value }
}

// Memverifikasi scan starts and stops from operational signal.
@MainActor
@Test func scanStartsAndStopsFromOperationalSignal() {
    let camera = SampleCameraController()
    let viewModel = ScanViewModel(camera: camera)

    viewModel.setOperational(true)
    #expect(camera.isRunning)
    #expect(camera.startCount == 1)

    viewModel.setOperational(false)
    #expect(!camera.isRunning)
    #expect(camera.stopCount == 1)
}

// Memverifikasi scan activity updates are idempotent.
@MainActor
@Test func scanActivityUpdatesAreIdempotent() {
    let camera = SampleCameraController()
    let viewModel = ScanViewModel(camera: camera)

    viewModel.setOperational(true)
    viewModel.setOperational(true)
    viewModel.setOperational(false)
    viewModel.setOperational(false)

    #expect(camera.startCount == 1)
    #expect(camera.stopCount == 1)
}

// Memverifikasi scan view model deinit stops camera.
@MainActor
@Test func scanViewModelDeinitStopsCamera() {
    let camera = SampleCameraController()
    let weakViewModel = WeakReference<ScanViewModel>(nil)
    do {
        let viewModel = ScanViewModel(camera: camera)
        weakViewModel.value = viewModel
        viewModel.setOperational(true)
    }

    #expect(weakViewModel.value == nil)
    #expect(!camera.isRunning)
    #expect(camera.stopCount == 1)
}

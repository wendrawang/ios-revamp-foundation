import ScanFeature
import Testing

private final class WeakReference<Object: AnyObject> {
    weak var value: Object?
    init(_ value: Object?) { self.value = value }
}

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

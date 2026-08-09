import ScanFeature
import Testing

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

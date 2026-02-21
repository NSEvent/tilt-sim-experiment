import Foundation

final class AppState: ObservableObject {
    let grid = Grid()
    let engine: SimulationEngine
    let accelerometer = Accelerometer()

    @Published var selectedElement: ElementType = .sand
    @Published var brushRadius: Int = 3
    @Published var isPaused: Bool = false
    @Published var drainMode: Bool = false
    @Published var showAccelBanner: Bool = false

    var gravityDirection: GravityDirection = .south
    var gravityX: Double = 0
    var gravityY: Double = 0

    init() {
        engine = SimulationEngine(grid: grid)
    }

    func startAccelerometer() {
        accelerometer.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            if !self.accelerometer.isAvailable {
                self.showAccelBanner = true
            }
        }
    }

    func updateGravity() {
        let (ax, ay) = accelerometer.gravity
        gravityX = ax
        gravityY = ay
        gravityDirection = GravityDirection.fromAccelerometer(x: ax, y: ay)
    }

    func clearGrid() {
        grid.clear()
    }
}

import Foundation

struct Cell {
    var element: ElementType = .empty
    var colorOffset: Int8 = 0
    var lifetime: Int16 = 0
    var initialLifetime: Int16 = 0
    var lastTick: UInt32 = 0
    var particleId: UInt32 = 0
}

final class Grid {
    static let width = 320
    static let height = 240
    static let count = width * height

    var cells: [Cell]
    var nextParticleId: UInt32 = 1

    init() {
        cells = [Cell](repeating: Cell(), count: Grid.count)
    }

    @inline(__always)
    func index(_ col: Int, _ row: Int) -> Int {
        row &* Grid.width &+ col
    }

    @inline(__always)
    subscript(col: Int, row: Int) -> Cell {
        get { cells[index(col, row)] }
        set { cells[index(col, row)] = newValue }
    }

    @inline(__always)
    func inBounds(col: Int, row: Int) -> Bool {
        col >= 0 && col < Grid.width && row >= 0 && row < Grid.height
    }

    func spawnParticle(element: ElementType, col: Int, row: Int, lifetime: Int? = nil) {
        var cell = Cell()
        cell.element = element
        cell.colorOffset = Int8.random(in: -15...15)
        let lt = lifetime ?? element.defaultLifetime
        cell.lifetime = Int16(lt)
        cell.initialLifetime = Int16(lt)
        cell.particleId = nextParticleId
        nextParticleId &+= 1
        self[col, row] = cell
    }

    func clear() {
        for i in 0..<Grid.count {
            cells[i] = Cell()
        }
    }
}

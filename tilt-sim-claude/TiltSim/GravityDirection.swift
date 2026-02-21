import Foundation

enum GravityDirection: CaseIterable {
    case south, north, east, west
    case southEast, southWest, northEast, northWest

    struct Delta {
        let dc: Int
        let dr: Int
    }

    var down: Delta {
        switch self {
        case .south:     return Delta(dc: 0, dr: 1)
        case .north:     return Delta(dc: 0, dr: -1)
        case .east:      return Delta(dc: 1, dr: 0)
        case .west:      return Delta(dc: -1, dr: 0)
        case .southEast: return Delta(dc: 1, dr: 1)
        case .southWest: return Delta(dc: -1, dr: 1)
        case .northEast: return Delta(dc: 1, dr: -1)
        case .northWest: return Delta(dc: -1, dr: -1)
        }
    }

    var downLeft: Delta {
        switch self {
        case .south:     return Delta(dc: -1, dr: 1)
        case .north:     return Delta(dc: 1, dr: -1)
        case .east:      return Delta(dc: 1, dr: 1)
        case .west:      return Delta(dc: -1, dr: -1)
        case .southEast: return Delta(dc: 0, dr: 1)
        case .southWest: return Delta(dc: -1, dr: 0)
        case .northEast: return Delta(dc: 1, dr: 0)
        case .northWest: return Delta(dc: 0, dr: -1)
        }
    }

    var downRight: Delta {
        switch self {
        case .south:     return Delta(dc: 1, dr: 1)
        case .north:     return Delta(dc: -1, dr: -1)
        case .east:      return Delta(dc: 1, dr: -1)
        case .west:      return Delta(dc: -1, dr: 1)
        case .southEast: return Delta(dc: 1, dr: 0)
        case .southWest: return Delta(dc: 0, dr: 1)
        case .northEast: return Delta(dc: 0, dr: -1)
        case .northWest: return Delta(dc: -1, dr: 0)
        }
    }

    var lateralLeft: Delta {
        switch self {
        case .south:     return Delta(dc: -1, dr: 0)
        case .north:     return Delta(dc: 1, dr: 0)
        case .east:      return Delta(dc: 0, dr: 1)
        case .west:      return Delta(dc: 0, dr: -1)
        case .southEast: return Delta(dc: -1, dr: 1)
        case .southWest: return Delta(dc: 1, dr: 1)
        case .northEast: return Delta(dc: -1, dr: -1)
        case .northWest: return Delta(dc: 1, dr: -1)
        }
    }

    var lateralRight: Delta {
        switch self {
        case .south:     return Delta(dc: 1, dr: 0)
        case .north:     return Delta(dc: -1, dr: 0)
        case .east:      return Delta(dc: 0, dr: -1)
        case .west:      return Delta(dc: 0, dr: 1)
        case .southEast: return Delta(dc: 1, dr: -1)
        case .southWest: return Delta(dc: -1, dr: -1)
        case .northEast: return Delta(dc: 1, dr: 1)
        case .northWest: return Delta(dc: -1, dr: 1)
        }
    }

    var up: Delta {
        let d = down
        return Delta(dc: -d.dc, dr: -d.dr)
    }

    var upLeft: Delta {
        let d = downRight
        return Delta(dc: -d.dc, dr: -d.dr)
    }

    var upRight: Delta {
        let d = downLeft
        return Delta(dc: -d.dc, dr: -d.dr)
    }

    /// Whether to process rows top-to-bottom (true) or bottom-to-top (false)
    var processTopFirst: Bool {
        switch self {
        case .north, .northEast, .northWest: return true
        case .south, .southEast, .southWest: return false
        case .east, .west: return Bool.random()
        }
    }

    static func fromAccelerometer(x: Double, y: Double) -> GravityDirection {
        // x positive = tilt right = gravity East
        // y positive = tilt away = gravity North (toward lower row indices)
        // y negative = tilt toward user = gravity South
        let gCol = x
        let gRow = -y
        let magnitude = sqrt(gCol * gCol + gRow * gRow)
        if magnitude < 0.05 { return .south }

        var angle = atan2(gRow, gCol)
        if angle < 0 { angle += 2 * .pi }

        let sector = Int((angle + .pi / 8) / (.pi / 4)) % 8
        switch sector {
        case 0: return .east
        case 1: return .southEast
        case 2: return .south
        case 3: return .southWest
        case 4: return .west
        case 5: return .northWest
        case 6: return .north
        case 7: return .northEast
        default: return .south
        }
    }
}

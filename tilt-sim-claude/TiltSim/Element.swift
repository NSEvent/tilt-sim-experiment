import Foundation

enum ElementType: UInt8, CaseIterable {
    case empty = 0
    case sand = 1
    case water = 2
    case stone = 3
    case wood = 4
    case fire = 5
    case smoke = 6
    case lava = 7
    case oil = 8
    case acid = 9
    case steam = 10
    case ice = 11
    case gunpowder = 12

    static let drawable: [ElementType] = allCases.filter { $0 != .empty }

    var name: String {
        switch self {
        case .empty: return "Empty"
        case .sand: return "Sand"
        case .water: return "Water"
        case .stone: return "Stone"
        case .wood: return "Wood"
        case .fire: return "Fire"
        case .smoke: return "Smoke"
        case .lava: return "Lava"
        case .oil: return "Oil"
        case .acid: return "Acid"
        case .steam: return "Steam"
        case .ice: return "Ice"
        case .gunpowder: return "Gunpowder"
        }
    }

    var category: ElementCategory {
        switch self {
        case .empty: return .solid
        case .sand, .gunpowder: return .powder
        case .water, .lava, .oil, .acid: return .liquid
        case .stone, .wood, .ice: return .solid
        case .fire, .smoke, .steam: return .gas
        }
    }

    var baseColor: (r: UInt8, g: UInt8, b: UInt8) {
        switch self {
        case .empty:     return (0x0D, 0x0D, 0x0D)
        case .sand:      return (0xE0, 0xC0, 0x80)
        case .water:     return (0x40, 0x90, 0xE0)
        case .stone:     return (0x80, 0x80, 0x80)
        case .wood:      return (0x8B, 0x5E, 0x3C)
        case .fire:      return (0xFF, 0x45, 0x00)
        case .smoke:     return (0xA0, 0xA0, 0xA0)
        case .lava:      return (0xFF, 0x33, 0x00)
        case .oil:       return (0x3D, 0x2B, 0x1F)
        case .acid:      return (0x80, 0xFF, 0x00)
        case .steam:     return (0xD0, 0xD8, 0xE0)
        case .ice:       return (0xC0, 0xE8, 0xFF)
        case .gunpowder: return (0x2A, 0x2A, 0x2A)
        }
    }

    var density: Int {
        switch self {
        case .empty: return 0
        case .sand: return 80
        case .water: return 50
        case .stone, .wood, .ice: return 100
        case .fire: return 5
        case .smoke: return 3
        case .lava: return 90
        case .oil: return 40
        case .acid: return 55
        case .steam: return 2
        case .gunpowder: return 75
        }
    }

    var defaultLifetime: Int {
        switch self {
        case .fire: return 60
        case .smoke: return 120
        case .steam: return 180
        default: return 0
        }
    }

    var isFlammable: Bool {
        switch self {
        case .wood, .oil, .gunpowder: return true
        default: return false
        }
    }
}

enum ElementCategory {
    case powder, liquid, solid, gas
}

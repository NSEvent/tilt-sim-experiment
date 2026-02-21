import Foundation

final class SimulationEngine {
    let grid: Grid
    var currentTick: UInt32 = 0
    private var chainExplosionCount = 0

    init(grid: Grid) {
        self.grid = grid
    }

    func tick(gravity: GravityDirection, drainMode: Bool) {
        currentTick &+= 1
        chainExplosionCount = 0

        let processTopFirst = gravity.processTopFirst
        let rowStart = processTopFirst ? 0 : Grid.height - 1
        let rowEnd = processTopFirst ? Grid.height : -1
        let rowStep = processTopFirst ? 1 : -1

        var row = rowStart
        while row != rowEnd {
            let leftToRight = Bool.random()
            let colStart = leftToRight ? 0 : Grid.width - 1
            let colEnd = leftToRight ? Grid.width : -1
            let colStep = leftToRight ? 1 : -1

            var col = colStart
            while col != colEnd {
                processCell(col: col, row: row, gravity: gravity)
                col &+= colStep
            }
            row &+= rowStep
        }

        if drainMode {
            drainEdges()
        }
    }

    private func processCell(col: Int, row: Int, gravity: GravityDirection) {
        let cell = grid[col, row]
        guard cell.element != .empty else { return }
        guard cell.lastTick != currentTick else { return }

        grid[col, row].lastTick = currentTick

        // Decrement lifetime
        if cell.lifetime > 0 {
            grid[col, row].lifetime -= 1
            if grid[col, row].lifetime <= 0 {
                grid[col, row] = Cell()
                return
            }
        }

        // Move based on category
        var newCol = col, newRow = row
        switch cell.element.category {
        case .powder:
            (newCol, newRow) = movePowder(col: col, row: row, gravity: gravity)
        case .liquid:
            (newCol, newRow) = moveLiquid(col: col, row: row, gravity: gravity)
        case .gas:
            (newCol, newRow) = moveGas(col: col, row: row, gravity: gravity)
        case .solid:
            break
        }

        checkInteractions(col: newCol, row: newRow)
    }

    // MARK: - Powder Movement

    private func movePowder(col: Int, row: Int, gravity: GravityDirection) -> (Int, Int) {
        let d = gravity.down
        // 1. Down
        if let result = tryMoveOrSwap(col: col, row: row, dc: d.dc, dr: d.dr, forPowder: true) {
            return result
        }
        // 2/3. Diagonal (random order)
        let dl = gravity.downLeft
        let dr = gravity.downRight
        let leftFirst = Bool.random()
        let first = leftFirst ? dl : dr
        let second = leftFirst ? dr : dl
        if let result = tryMoveOrSwap(col: col, row: row, dc: first.dc, dr: first.dr, forPowder: true) {
            return result
        }
        if let result = tryMoveOrSwap(col: col, row: row, dc: second.dc, dr: second.dr, forPowder: true) {
            return result
        }
        return (col, row)
    }

    // MARK: - Liquid Movement

    private func moveLiquid(col: Int, row: Int, gravity: GravityDirection) -> (Int, Int) {
        let d = gravity.down
        // 1. Down
        if let result = tryMoveOrSwapLiquid(col: col, row: row, dc: d.dc, dr: d.dr) {
            return result
        }
        // 2/3. Diagonals
        let dl = gravity.downLeft
        let dr = gravity.downRight
        let leftFirst = Bool.random()
        let first = leftFirst ? dl : dr
        let second = leftFirst ? dr : dl
        if let result = tryMoveOrSwapLiquid(col: col, row: row, dc: first.dc, dr: first.dr) {
            return result
        }
        if let result = tryMoveOrSwapLiquid(col: col, row: row, dc: second.dc, dr: second.dr) {
            return result
        }
        // 4/5. Lateral spread (up to 3 cells)
        let ll = gravity.lateralLeft
        let lr = gravity.lateralRight
        let spreadLeftFirst = Bool.random()
        let firstLat = spreadLeftFirst ? ll : lr
        let secondLat = spreadLeftFirst ? lr : ll
        if let result = tryLateralSpread(col: col, row: row, dc: firstLat.dc, dr: firstLat.dr) {
            return result
        }
        if let result = tryLateralSpread(col: col, row: row, dc: secondLat.dc, dr: secondLat.dr) {
            return result
        }
        return (col, row)
    }

    // MARK: - Gas Movement

    private func moveGas(col: Int, row: Int, gravity: GravityDirection) -> (Int, Int) {
        var nc = col, nr = row

        let u = gravity.up
        // 1. Up
        if let result = tryMoveEmpty(col: nc, row: nr, dc: u.dc, dr: u.dr) {
            nc = result.0; nr = result.1
        } else {
            // 2/3. Up-diagonals
            let ul = gravity.upLeft
            let ur = gravity.upRight
            let leftFirst = Bool.random()
            let first = leftFirst ? ul : ur
            let second = leftFirst ? ur : ul
            if let result = tryMoveEmpty(col: nc, row: nr, dc: first.dc, dr: first.dr) {
                nc = result.0; nr = result.1
            } else if let result = tryMoveEmpty(col: nc, row: nr, dc: second.dc, dr: second.dr) {
                nc = result.0; nr = result.1
            } else {
                // 4/5. Lateral
                let ll = gravity.lateralLeft
                let lr = gravity.lateralRight
                let latLeftFirst = Bool.random()
                let firstLat = latLeftFirst ? ll : lr
                let secondLat = latLeftFirst ? lr : ll
                if let result = tryMoveEmpty(col: nc, row: nr, dc: firstLat.dc, dr: firstLat.dr) {
                    nc = result.0; nr = result.1
                } else if let result = tryMoveEmpty(col: nc, row: nr, dc: secondLat.dc, dr: secondLat.dr) {
                    nc = result.0; nr = result.1
                }
            }
        }

        // Gas jitter: 15% chance of additional lateral move (applied after all movement)
        if Double.random(in: 0..<1) < 0.15 {
            let ll = gravity.lateralLeft
            let lr = gravity.lateralRight
            let dir = Bool.random() ? ll : lr
            let jc = nc + dir.dc, jr = nr + dir.dr
            if grid.inBounds(col: jc, row: jr) && grid[jc, jr].element == .empty {
                moveParticle(fromCol: nc, fromRow: nr, toCol: jc, toRow: jr)
                nc = jc; nr = jr
            }
        }

        return (nc, nr)
    }

    // MARK: - Movement Helpers

    private func tryMoveOrSwap(col: Int, row: Int, dc: Int, dr: Int, forPowder: Bool) -> (Int, Int)? {
        let nc = col + dc
        let nr = row + dr
        guard grid.inBounds(col: nc, row: nr) else { return nil }
        let target = grid[nc, nr]
        if target.element == .empty {
            moveParticle(fromCol: col, fromRow: row, toCol: nc, toRow: nr)
            return (nc, nr)
        }
        if forPowder && target.element.category == .liquid && target.element.density < grid[col, row].element.density {
            swapParticles(col1: col, row1: row, col2: nc, row2: nr)
            return (nc, nr)
        }
        return nil
    }

    private func tryMoveOrSwapLiquid(col: Int, row: Int, dc: Int, dr: Int) -> (Int, Int)? {
        let nc = col + dc
        let nr = row + dr
        guard grid.inBounds(col: nc, row: nr) else { return nil }
        let target = grid[nc, nr]
        if target.element == .empty {
            moveParticle(fromCol: col, fromRow: row, toCol: nc, toRow: nr)
            return (nc, nr)
        }
        if target.element.category == .liquid && target.element.density < grid[col, row].element.density {
            swapParticles(col1: col, row1: row, col2: nc, row2: nr)
            return (nc, nr)
        }
        return nil
    }

    private func tryMoveEmpty(col: Int, row: Int, dc: Int, dr: Int) -> (Int, Int)? {
        let nc = col + dc
        let nr = row + dr
        guard grid.inBounds(col: nc, row: nr) else { return nil }
        if grid[nc, nr].element == .empty {
            moveParticle(fromCol: col, fromRow: row, toCol: nc, toRow: nr)
            return (nc, nr)
        }
        return nil
    }

    private func tryLateralSpread(col: Int, row: Int, dc: Int, dr: Int) -> (Int, Int)? {
        // Check first cell - if blocked, no spread
        let fc = col + dc
        let fr = row + dr
        guard grid.inBounds(col: fc, row: fr) else { return nil }
        guard grid[fc, fr].element == .empty else { return nil }

        // Find furthest empty cell in this direction (up to spread rate 3)
        var bestCol = fc
        var bestRow = fr
        for i in 2...3 {
            let nc = col + dc * i
            let nr = row + dr * i
            guard grid.inBounds(col: nc, row: nr) else { break }
            guard grid[nc, nr].element == .empty else { break }
            bestCol = nc
            bestRow = nr
        }
        moveParticle(fromCol: col, fromRow: row, toCol: bestCol, toRow: bestRow)
        return (bestCol, bestRow)
    }

    private func moveParticle(fromCol: Int, fromRow: Int, toCol: Int, toRow: Int) {
        var particle = grid[fromCol, fromRow]
        particle.lastTick = currentTick
        grid[toCol, toRow] = particle
        grid[fromCol, fromRow] = Cell()
    }

    private func swapParticles(col1: Int, row1: Int, col2: Int, row2: Int) {
        var a = grid[col1, row1]
        var b = grid[col2, row2]
        a.lastTick = currentTick
        b.lastTick = currentTick
        grid[col1, row1] = b
        grid[col2, row2] = a
    }

    // MARK: - Interactions

    private func checkInteractions(col: Int, row: Int) {
        let cell = grid[col, row]
        guard cell.element != .empty else { return }

        let neighbors: [(Int, Int)] = [(col - 1, row), (col + 1, row), (col, row - 1), (col, row + 1)]

        switch cell.element {
        case .fire:
            for (nc, nr) in neighbors {
                guard grid.inBounds(col: nc, row: nr) else { continue }
                let ne = grid[nc, nr].element
                switch ne {
                case .wood where Double.random(in: 0..<1) < 0.15:
                    grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 60)
                    grid[nc, nr].lastTick = currentTick
                case .oil where Double.random(in: 0..<1) < 0.40:
                    grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 60)
                    grid[nc, nr].lastTick = currentTick
                case .gunpowder where Double.random(in: 0..<1) < 0.80:
                    grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 20)
                    grid[nc, nr].lastTick = currentTick
                    triggerExplosion(col: nc, row: nr)
                case .ice where Double.random(in: 0..<1) < 0.10:
                    grid.spawnParticle(element: .water, col: nc, row: nr)
                    grid[nc, nr].lastTick = currentTick
                default: break
                }
            }

        case .lava:
            for (nc, nr) in neighbors {
                guard grid.inBounds(col: nc, row: nr) else { continue }
                let ne = grid[nc, nr].element
                switch ne {
                case .wood where Double.random(in: 0..<1) < 0.30:
                    grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 60)
                    grid[nc, nr].lastTick = currentTick
                case .oil where Double.random(in: 0..<1) < 0.50:
                    grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 60)
                    grid[nc, nr].lastTick = currentTick
                case .water:
                    // Lava → Stone, Water → Steam
                    grid.spawnParticle(element: .stone, col: col, row: row)
                    grid[col, row].lastTick = currentTick
                    grid.spawnParticle(element: .steam, col: nc, row: nr, lifetime: 180)
                    grid[nc, nr].lastTick = currentTick
                    return // This particle is now stone, stop checking
                case .ice:
                    grid.spawnParticle(element: .stone, col: col, row: row)
                    grid[col, row].lastTick = currentTick
                    grid.spawnParticle(element: .water, col: nc, row: nr)
                    grid[nc, nr].lastTick = currentTick
                    return
                default: break
                }
            }

        case .acid:
            for (nc, nr) in neighbors {
                guard grid.inBounds(col: nc, row: nr) else { continue }
                let ne = grid[nc, nr].element
                if ne != .empty && ne != .acid && Double.random(in: 0..<1) < 0.20 {
                    grid[nc, nr] = Cell()
                    // Acid consumed 10% of the time
                    if Double.random(in: 0..<1) < 0.10 {
                        grid[col, row] = Cell()
                        return
                    }
                }
            }

        case .steam:
            // Self-check for condensation
            if cell.lifetime > 0 && cell.lifetime < 60 && Double.random(in: 0..<1) < 0.005 {
                grid.spawnParticle(element: .water, col: col, row: row)
                grid[col, row].lastTick = currentTick
            }

        default:
            break
        }
    }

    // MARK: - Explosion

    private func triggerExplosion(col: Int, row: Int) {
        guard chainExplosionCount < 20 else { return }
        chainExplosionCount += 1

        for dr in -6...6 {
            for dc in -6...6 {
                let distSq = dr * dr + dc * dc
                guard distSq <= 36 else { continue }
                let nc = col + dc
                let nr = row + dr
                guard grid.inBounds(col: nc, row: nr) else { continue }

                let e = grid[nc, nr].element
                if e == .gunpowder {
                    grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 15)
                    grid[nc, nr].lastTick = currentTick
                    triggerExplosion(col: nc, row: nr)
                } else if e.category == .solid {
                    if Double.random(in: 0..<1) < 0.50 {
                        grid[nc, nr] = Cell()
                    }
                } else if e != .empty && e != .fire {
                    grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 15)
                    grid[nc, nr].lastTick = currentTick
                } else if e == .empty {
                    if Double.random(in: 0..<1) < 0.30 {
                        grid.spawnParticle(element: .fire, col: nc, row: nr, lifetime: 15)
                        grid[nc, nr].lastTick = currentTick
                    }
                }
            }
        }
    }

    // MARK: - Drain

    private func drainEdges() {
        for col in 0..<Grid.width {
            if grid[col, 0].element != .empty { grid[col, 0] = Cell() }
            if grid[col, Grid.height - 1].element != .empty { grid[col, Grid.height - 1] = Cell() }
        }
        for row in 1..<(Grid.height - 1) {
            if grid[0, row].element != .empty { grid[0, row] = Cell() }
            if grid[Grid.width - 1, row].element != .empty { grid[Grid.width - 1, row] = Cell() }
        }
    }
}

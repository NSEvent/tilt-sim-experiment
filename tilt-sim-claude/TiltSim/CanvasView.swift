import AppKit
import SwiftUI

struct SimulationCanvas: NSViewRepresentable {
    @ObservedObject var appState: AppState

    func makeNSView(context: Context) -> SimulationNSView {
        let view = SimulationNSView(appState: appState)
        // Make this view the first responder for key events
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: SimulationNSView, context: Context) {}
}

final class SimulationNSView: NSView {
    let appState: AppState
    private var pixelBuffer: [UInt8]
    private var displayTimer: Timer?
    private var lastFrameTime: CFAbsoluteTime = 0
    private var tickAccumulator: Double = 0
    private let tickInterval: Double = 1.0 / 60.0

    // Mouse tracking
    private var lastGridPos: (col: Int, row: Int)?
    private var isDrawing = false
    private var isErasing = false
    private var mouseGridPos: (col: Int, row: Int)?
    private var trackingArea: NSTrackingArea?

    init(appState: AppState) {
        self.appState = appState
        self.pixelBuffer = [UInt8](repeating: 0, count: Grid.width * Grid.height * 4)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard displayTimer == nil else { return }
        lastFrameTime = CFAbsoluteTimeGetCurrent()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.onFrame()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func removeFromSuperview() {
        displayTimer?.invalidate()
        displayTimer = nil
        super.removeFromSuperview()
    }

    // MARK: - Frame Loop

    private func onFrame() {
        let now = CFAbsoluteTimeGetCurrent()
        let dt = min(now - lastFrameTime, 0.1)
        lastFrameTime = now

        // Update gravity from accelerometer
        appState.updateGravity()

        // Run simulation ticks
        if !appState.isPaused {
            tickAccumulator += dt
            var ticks = 0
            while tickAccumulator >= tickInterval && ticks < 3 {
                appState.engine.tick(gravity: appState.gravityDirection, drainMode: appState.drainMode)
                tickAccumulator -= tickInterval
                ticks += 1
            }
            if tickAccumulator > tickInterval * 3 {
                tickAccumulator = 0
            }
        }

        updatePixelBuffer()
        needsDisplay = true
    }

    // MARK: - Pixel Buffer

    private func updatePixelBuffer() {
        let tick = appState.engine.currentTick
        let grid = appState.grid

        for row in 0..<Grid.height {
            for col in 0..<Grid.width {
                let cell = grid[col, row]
                let offset = (row * Grid.width + col) * 4
                let (r, g, b) = colorForCell(cell, currentTick: tick)
                pixelBuffer[offset] = r
                pixelBuffer[offset + 1] = g
                pixelBuffer[offset + 2] = b
                pixelBuffer[offset + 3] = 255
            }
        }
    }

    private func colorForCell(_ cell: Cell, currentTick: UInt32) -> (UInt8, UInt8, UInt8) {
        guard cell.element != .empty else { return (0x0D, 0x0D, 0x0D) }

        var r: Int, g: Int, b: Int

        if cell.element == .fire && cell.initialLifetime > 0 {
            let t = 1.0 - Double(cell.lifetime) / Double(cell.initialLifetime)
            let (fr, fg, fb) = fireColor(t: t)
            r = Int(fr) + Int(cell.colorOffset)
            g = Int(fg) + Int(cell.colorOffset)
            b = Int(fb) + Int(cell.colorOffset)
        } else {
            let base = cell.element.baseColor
            r = Int(base.r) + Int(cell.colorOffset)
            g = Int(base.g) + Int(cell.colorOffset)
            b = Int(base.b) + Int(cell.colorOffset)
        }

        if cell.element == .lava {
            let osc = sin(Double(currentTick) * 0.1 + Double(cell.particleId) * 0.7) * 20.0
            r += Int(osc)
            g += Int(osc)
            b += Int(osc)
        }

        return (
            UInt8(max(0, min(255, r))),
            UInt8(max(0, min(255, g))),
            UInt8(max(0, min(255, b)))
        )
    }

    private func fireColor(t: Double) -> (UInt8, UInt8, UInt8) {
        // 0 → #FF4500, 0.5 → #FFD700, 1.0 → #330000
        let r, g, b: Double
        if t < 0.5 {
            let s = t * 2.0
            r = 255.0
            g = 69.0 + s * (215.0 - 69.0)
            b = 0.0
        } else {
            let s = (t - 0.5) * 2.0
            r = 255.0 + s * (51.0 - 255.0)
            g = 215.0 + s * (0.0 - 215.0)
            b = 0.0
        }
        return (UInt8(max(0, min(255, r))), UInt8(max(0, min(255, g))), UInt8(max(0, min(255, b))))
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background (letterbox color)
        ctx.setFillColor(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0, alpha: 1)
        ctx.fill(bounds)

        // Create CGImage from pixel buffer
        let gridRect = calculateGridRect()
        if let image = createGridImage() {
            ctx.interpolationQuality = .none
            // In flipped view, need to flip image drawing
            ctx.saveGState()
            ctx.translateBy(x: gridRect.minX, y: gridRect.minY + gridRect.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: gridRect.width, height: gridRect.height))
            ctx.restoreGState()
        }

        // Gravity indicator
        drawGravityIndicator(ctx, gridRect: gridRect)

        // Brush cursor
        drawBrushCursor(ctx, gridRect: gridRect)
    }

    private func createGridImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        return pixelBuffer.withUnsafeBufferPointer { bufPtr -> CGImage? in
            guard let baseAddress = bufPtr.baseAddress else { return nil }
            guard let provider = CGDataProvider(data: Data(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress),
                count: bufPtr.count,
                deallocator: .none
            ) as CFData) else { return nil }
            return CGImage(
                width: Grid.width,
                height: Grid.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: Grid.width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    }

    func calculateGridRect() -> CGRect {
        let viewW = bounds.width
        let viewH = bounds.height
        let gridAspect: CGFloat = 4.0 / 3.0

        var gridW: CGFloat
        var gridH: CGFloat

        if viewW / viewH > gridAspect {
            // View is wider than 4:3 → pillarbox
            gridH = viewH
            gridW = viewH * gridAspect
        } else {
            // View is taller than 4:3 → letterbox
            gridW = viewW
            gridH = viewW / gridAspect
        }

        let x = (viewW - gridW) / 2
        let y = (viewH - gridH) / 2
        return CGRect(x: x, y: y, width: gridW, height: gridH)
    }

    // MARK: - Gravity Indicator

    private func drawGravityIndicator(_ ctx: CGContext, gridRect: CGRect) {
        let diameter: CGFloat = 48
        let padding: CGFloat = 12
        let cx = gridRect.maxX - padding - diameter / 2
        let cy = gridRect.minY + padding + diameter / 2

        // Circle background
        ctx.saveGState()
        ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        ctx.fillEllipse(in: CGRect(x: cx - diameter / 2, y: cy - diameter / 2, width: diameter, height: diameter))
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.3)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: cx - diameter / 2, y: cy - diameter / 2, width: diameter, height: diameter))

        // Dot showing gravity direction
        let maxOffset = diameter / 2 - 8
        let gx = appState.gravityX
        let gy = appState.gravityY
        let magnitude = sqrt(gx * gx + gy * gy)

        let dotX: CGFloat
        let dotY: CGFloat
        if magnitude < 0.05 {
            // Dead zone → gravity is south → dot at bottom center
            dotX = cx
            dotY = cy + maxOffset
        } else {
            let scale = min(1.0, magnitude / 1.0)
            // gx positive → dot moves right
            // gy positive (tilt away = north) → dot moves up (decrease y in flipped view)
            // gy negative (tilt toward = south) → dot moves down (increase y)
            dotX = cx + CGFloat(gx * scale) * maxOffset
            dotY = cy - CGFloat(gy * scale) * maxOffset
        }

        let dotSize: CGFloat = 8
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fillEllipse(in: CGRect(x: dotX - dotSize / 2, y: dotY - dotSize / 2, width: dotSize, height: dotSize))
        ctx.restoreGState()
    }

    // MARK: - Brush Cursor

    private func drawBrushCursor(_ ctx: CGContext, gridRect: CGRect) {
        guard let pos = mouseGridPos else { return }
        let cellW = gridRect.width / CGFloat(Grid.width)
        let cellH = gridRect.height / CGFloat(Grid.height)
        let radius = CGFloat(appState.brushRadius)

        let centerX = gridRect.minX + (CGFloat(pos.col) + 0.5) * cellW
        let centerY = gridRect.minY + (CGFloat(pos.row) + 0.5) * cellH
        let radiusPx = radius * cellW

        ctx.saveGState()
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(
            x: centerX - radiusPx, y: centerY - radiusPx,
            width: radiusPx * 2, height: radiusPx * 2
        ))
        ctx.restoreGState()
    }

    // MARK: - Mouse Input

    private func gridPosition(from event: NSEvent) -> (col: Int, row: Int)? {
        let point = convert(event.locationInWindow, from: nil)
        let gridRect = calculateGridRect()
        guard gridRect.contains(point) else { return nil }

        let col = Int((point.x - gridRect.minX) / gridRect.width * CGFloat(Grid.width))
        let row = Int((point.y - gridRect.minY) / gridRect.height * CGFloat(Grid.height))
        return (
            col: max(0, min(Grid.width - 1, col)),
            row: max(0, min(Grid.height - 1, row))
        )
    }

    override func mouseDown(with event: NSEvent) {
        isDrawing = true
        isErasing = event.modifierFlags.contains(.control)
        if let pos = gridPosition(from: event) {
            applyBrush(at: pos)
            lastGridPos = pos
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pos = gridPosition(from: event) else { return }
        mouseGridPos = pos
        if let last = lastGridPos {
            let points = bresenhamLine(from: last, to: pos)
            for p in points {
                applyBrush(at: p)
            }
        } else {
            applyBrush(at: pos)
        }
        lastGridPos = pos
    }

    override func mouseUp(with event: NSEvent) {
        isDrawing = false
        isErasing = false
        lastGridPos = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        isDrawing = true
        isErasing = true
        if let pos = gridPosition(from: event) {
            applyBrush(at: pos)
            lastGridPos = pos
        }
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard let pos = gridPosition(from: event) else { return }
        mouseGridPos = pos
        if let last = lastGridPos {
            let points = bresenhamLine(from: last, to: pos)
            for p in points {
                applyBrush(at: p)
            }
        } else {
            applyBrush(at: pos)
        }
        lastGridPos = pos
    }

    override func rightMouseUp(with event: NSEvent) {
        isDrawing = false
        isErasing = false
        lastGridPos = nil
    }

    override func mouseMoved(with event: NSEvent) {
        mouseGridPos = gridPosition(from: event)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if delta > 0 {
            appState.brushRadius = min(20, appState.brushRadius + 1)
        } else if delta < 0 {
            appState.brushRadius = max(1, appState.brushRadius - 1)
        }
    }

    // MARK: - Brush Application

    private func applyBrush(at pos: (col: Int, row: Int)) {
        let r = appState.brushRadius
        let grid = appState.grid

        for dr in -r...r {
            for dc in -r...r {
                guard dr * dr + dc * dc <= r * r else { continue }
                let c = pos.col + dc
                let rr = pos.row + dr
                guard grid.inBounds(col: c, row: rr) else { continue }

                if isErasing {
                    grid[c, rr] = Cell()
                } else if grid[c, rr].element == .empty {
                    grid.spawnParticle(element: appState.selectedElement, col: c, row: rr)
                }
            }
        }
    }

    // MARK: - Bresenham Line

    private func bresenhamLine(from a: (col: Int, row: Int), to b: (col: Int, row: Int)) -> [(col: Int, row: Int)] {
        var points: [(col: Int, row: Int)] = []
        var x0 = a.col, y0 = a.row
        let x1 = b.col, y1 = b.row
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy

        while true {
            points.append((col: x0, row: y0))
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
        return points
    }
}

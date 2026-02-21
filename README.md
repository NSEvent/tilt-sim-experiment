# TiltSim

A falling-sand game where you physically tilt your MacBook to control gravity.

Built in Swift with zero dependencies. Reads the Apple Silicon accelerometer directly via IOKit to turn your laptop into a particle physics toy.

12 elements (sand, water, lava, gunpowder, acid, ...) interact with each other — fire ignites wood and oil, lava solidifies on water contact, gunpowder chain-explodes, acid dissolves everything. Tilt your MacBook and watch it all flow.

<p align="center">
  <img src="demo.gif" alt="TiltSim demo — tilting MacBook to control gravity" width="600">
</p>

## Quick Start

```bash
git clone https://github.com/NSEvent/tilt-sim-experiment.git
cd tilt-sim-experiment/tilt-sim-claude
make run
```

That's it. `make run` builds and launches the app. Tilt control works automatically on Apple Silicon MacBooks.

> **No MacBook?** The app still works — gravity just always points down.

### Requirements

- macOS 14+ (Sonoma)
- Swift 5.9+ (ships with Xcode or Xcode Command Line Tools)
- Apple Silicon MacBook for tilt control (M1/M2/M3/M4)

## Controls

| Input | Action |
|-------|--------|
| **Left click + drag** | Draw selected element |
| **Right click** (or Ctrl+click) | Erase |
| **Scroll wheel** | Adjust brush size |
| `[` / `]` | Decrease / increase brush size |
| `1`–`9`, `0`, `-`, `=` | Select element |
| `Space` | Pause / resume |
| `D` | Toggle drain mode (particles removed at edges) |
| `Cmd+Delete` | Clear all particles |

## Elements

| Element | Behavior |
|---------|----------|
| **Sand** | Falls, piles up, sinks through liquids |
| **Water** | Flows and spreads laterally |
| **Stone** | Immovable wall (destroyed by acid) |
| **Wood** | Solid, flammable |
| **Fire** | Rises, ignites wood/oil/gunpowder, melts ice |
| **Smoke** | Rises and drifts, fades after 120 ticks |
| **Lava** | Ignites flammable materials, turns to stone on water contact (+ steam) |
| **Oil** | Floats on water, highly flammable |
| **Acid** | Dissolves everything it touches |
| **Steam** | Produced by lava+water, condenses back to water |
| **Ice** | Melted by fire/lava into water |
| **Gunpowder** | Explosive — chain detonation with radius 6, up to 20 chain reactions |

## How the Tilt Works

Apple Silicon MacBooks have a built-in accelerometer (`AppleSPUHIDDevice`). The app reads raw sensor data via IOKit HID, applies exponential moving average smoothing, and maps the tilt angle to one of 8 gravity directions.

The gravity indicator in the top-right corner shows a dot representing the current tilt vector.

No special permissions required — the IOKit HID service is accessible without root.

## Architecture

~1,500 lines of Swift across 10 files. No Xcode project — just Swift Package Manager.

- **Grid**: 320x240 cell grid, each cell stores element type, color offset, lifetime, tick counter
- **Simulation**: 60 ticks/sec fixed timestep. Processes cells bottom-up (flipped when gravity reverses). Random left/right scan order prevents directional bias
- **Rendering**: Direct pixel buffer to `CGImage` with nearest-neighbor scaling. 60fps display timer
- **Accelerometer**: Dedicated thread reading IOKit HID reports, EMA-smoothed (alpha=0.15)
- **UI**: SwiftUI toolbar + AppKit `NSView` canvas. Bresenham line interpolation for smooth brush strokes

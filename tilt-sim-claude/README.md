# TiltSim

A real-time 2D particle physics sandbox for macOS where gravity is controlled by physically tilting your MacBook.

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon MacBook (M1/M2/M3/M4) for accelerometer
- Xcode Command Line Tools (for `swift build`)

## Build & Run

```bash
# Build
swift build -c release

# Run with accelerometer (requires root for IOKit HID access)
sudo .build/release/TiltSim

# Run without accelerometer (static gravity mode)
.build/release/TiltSim
```

Or use the Makefile:
```bash
make build   # Build release
make run     # sudo run
```

## Controls

| Input | Action |
|-------|--------|
| Left click + drag | Draw selected element |
| Right click + drag (or Ctrl+click) | Erase |
| Scroll wheel | Adjust brush size |
| `[` / `]` | Decrease / increase brush size |
| `1`–`9`, `0`, `-`, `=` | Select element (Sand, Water, Stone, Wood, Fire, Smoke, Lava, Oil, Acid, Steam, Ice, Gunpowder) |
| `Space` | Pause / Resume simulation |
| `D` | Toggle drain mode (edge particles removed) |
| `Cmd+Delete` | Clear all particles |

## Elements

| Element | Type | Interactions |
|---------|------|-------------|
| Sand | Powder | Falls, piles up, slides diagonally |
| Water | Liquid | Falls, spreads laterally (3 cells) |
| Stone | Solid | Immovable, destroyed by acid |
| Wood | Solid | Flammable (fire, lava) |
| Fire | Gas | Rises, ignites wood/oil/gunpowder, melts ice. Lifetime: 60 ticks |
| Smoke | Gas | Rises, drifts. Lifetime: 120 ticks |
| Lava | Liquid | Ignites flammable materials, solidifies on water contact → Stone + Steam |
| Oil | Liquid | Floats on water, flammable |
| Acid | Liquid | Dissolves everything except acid (20%/tick) |
| Steam | Gas | Produced by lava+water, condenses back to water. Lifetime: 180 ticks |
| Ice | Solid | Melted by fire/lava into water |
| Gunpowder | Powder | Flammable, explosive (radius 6, chain limit 20) |

## Accelerometer

The app reads the Apple Silicon accelerometer via IOKit HID (`AppleSPUHIDDevice`). This requires root privileges. Without root access, the app runs in static gravity mode (gravity always points down).

Tilt your MacBook to change gravity direction — particles will fall toward the tilt direction. The gravity indicator circle in the top-right corner shows the current gravity vector.

## Architecture

- **Simulation**: 320×240 grid, 60 ticks/sec fixed timestep, bottom-up processing order
- **Rendering**: Core Graphics pixel buffer with nearest-neighbor scaling
- **Accelerometer**: IOKit HID with exponential moving average smoothing (α=0.15)
- **UI**: SwiftUI toolbar + AppKit NSView canvas

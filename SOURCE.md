# TiltSim — Complete Specification

## 1. What This Is

A macOS desktop application. A real-time 2D particle physics sandbox where gravity is controlled by physically tilting the MacBook. The user draws elements (sand, water, lava, etc.) onto a grid, and particles simulate falling, flowing, burning, and interacting — with the direction of gravity determined by the laptop’s built-in accelerometer.

This is a toy, not a game. There is no win state, no score, no levels. The user creates scenarios and watches emergent physics play out.

-----

## 2. Platform & Runtime

- **OS:** macOS 14.0+ (Sonoma or later)
- **Hardware:** Apple Silicon MacBook (M1/M2/M3/M4) with built-in MEMS accelerometer
- **Window:** Resizable, with a minimum size of 960×640 pixels
- **Frame rate target:** 60 FPS for rendering; simulation tick rate is independent (see Section 5)

-----

## 3. The Grid

### 3.1 Structure

The simulation operates on a fixed-size 2D grid of square cells.

- **Grid dimensions:** 320 columns × 240 rows (76,800 cells total)
- **Cell size on screen:** Determined dynamically. The grid scales to fill the available canvas area (the window minus the toolbar) while preserving a 4:3 aspect ratio. Each cell renders as a square. If the window aspect ratio does not match 4:3, the grid is centered with equal letterboxing/pillarboxing on the shorter axis. The letterbox/pillarbox color is `#1A1A1A`.
- **Coordinate system:** Column 0, Row 0 is the top-left corner of the grid. Column index increases rightward. Row index increases downward.

### 3.2 Cell State

Each cell contains exactly one of the following:

- **Empty** (nothing; rendered as background)
- **A particle of a specific element type** (see Section 4)

A cell cannot hold more than one particle. There are no fractional positions — particles occupy whole cells.

### 3.3 Boundary Behavior

The grid edges are solid walls. Particles that would move outside the grid boundaries remain in their current cell. They do not wrap, disappear, or teleport.

**Exception — Drain mode:** See Section 8.4. When drain mode is active, particles that reach any edge cell (row 0, row 239, column 0, column 319) are deleted on the next simulation tick.

-----

## 4. Elements

### 4.1 Element Categories

There are three movement categories:

|Category  |Behavior                                                              |
|----------|----------------------------------------------------------------------|
|**Powder**|Falls in the gravity direction. Piles up. Slides diagonally off peaks.|
|**Liquid**|Falls in the gravity direction. Spreads laterally when it cannot fall.|
|**Solid** |Never moves. Permanent until destroyed by an interaction.             |
|**Gas**   |Rises against gravity. Spreads laterally. Dissipates over time.       |

### 4.2 Element Definitions

Each element has:

- A **name**
- A **category** (powder, liquid, solid, gas)
- A **base color** (hex, see rendering in Section 6)
- A **density** (integer, 1–100; determines which particle sinks below which)
- A **lifetime** (in simulation ticks; 0 means infinite/permanent)
- **Interaction rules** (see Section 4.4)

#### Element Table

|Name     |Category|Base Color|Density|Lifetime|Notes                                  |
|---------|--------|----------|-------|--------|---------------------------------------|
|Sand     |Powder  |`#E0C080` |80     |0       |                                       |
|Water    |Liquid  |`#4090E0` |50     |0       |                                       |
|Stone    |Solid   |`#808080` |100    |0       |Indestructible except by Acid          |
|Wood     |Solid   |`#8B5E3C` |100    |0       |Flammable                              |
|Fire     |Gas     |`#FF4500` |5      |60      |Rises. Ignites flammable neighbors.    |
|Smoke    |Gas     |`#A0A0A0` |3      |120     |Produced by fire. No interactions.     |
|Lava     |Liquid  |`#FF3300` |90     |0       |Ignites flammable. Solidifies on water.|
|Oil      |Liquid  |`#3D2B1F` |40     |0       |Floats on water. Flammable.            |
|Acid     |Liquid  |`#80FF00` |55     |0       |Dissolves everything except Acid.      |
|Steam    |Gas     |`#D0D8E0` |2      |180     |Produced by water+lava. Condenses.     |
|Ice      |Solid   |`#C0E8FF` |100    |0       |Melted by lava/fire into water.        |
|Gunpowder|Powder  |`#2A2A2A` |75     |0       |Flammable. Explosive (see 4.4).        |

### 4.3 Movement Rules

Movement is evaluated once per simulation tick per particle, in the order defined in Section 5.

**“Down” means the current gravity direction.** If the accelerometer says gravity points left, then “down” is left, “up” is right, and “lateral” means up/down on screen. All movement descriptions below use relative terms: down, up, left-lateral, right-lateral.

#### 4.3.1 Powder Movement

Each tick, a powder particle attempts to move in this priority order:

1. **Down 1 cell.** If the cell directly below (in the gravity direction) is empty OR contains a liquid with lower density → move there (swap with the liquid if present).
1. **Down-left-lateral 1 cell (diagonal).** Same empty/swap rules. Choose down+left-lateral.
1. **Down-right-lateral 1 cell (diagonal).** Same empty/swap rules.
1. **Stay.** If none of the above are possible, the particle does not move.

If both step 2 and step 3 are valid, choose one at random (50/50 per tick).

#### 4.3.2 Liquid Movement

Each tick, a liquid particle attempts:

1. **Down 1 cell.** If empty or contains a liquid with strictly lower density → move (swap if needed).
1. **Down-left-lateral diagonal.** Same rules.
1. **Down-right-lateral diagonal.** Same rules.
1. **Left-lateral 1 cell.** If empty → move.
1. **Right-lateral 1 cell.** If empty → move.
1. **Stay.**

If both options at the same priority level are valid (e.g., both diagonals, or both laterals), choose one at random (50/50).

**Liquid spread distance:** When a liquid moves laterally (steps 4–5), it has a **spread rate of 3** — meaning in a single tick, it will continue checking cells in the chosen lateral direction up to 3 cells away, moving to the furthest empty cell found in an unbroken line. If the first lateral cell is occupied, it does not move laterally at all.

#### 4.3.3 Solid Movement

Solids never move. They occupy their cell permanently unless destroyed by an interaction rule.

#### 4.3.4 Gas Movement

Each tick, a gas particle attempts:

1. **Up 1 cell** (opposite of gravity). If empty → move.
1. **Up-left-lateral diagonal.** If empty → move.
1. **Up-right-lateral diagonal.** If empty → move.
1. **Left-lateral 1 cell.** If empty → move.
1. **Right-lateral 1 cell.** If empty → move.
1. **Stay.**

Random tiebreaking at each priority level, same as liquid.

**Gas jitter:** Each tick, after the above movement, a gas particle has a 15% chance of additionally moving 1 cell in a random lateral direction (if that cell is empty). This creates a natural drifting effect.

**Lifetime:** Each tick, a gas particle’s remaining lifetime decrements by 1. When lifetime reaches 0, the particle is deleted (cell becomes empty). This decrement happens regardless of whether the particle moved.

### 4.4 Interaction Rules

Interactions are checked AFTER a particle has moved (or attempted to move) during its tick. A particle checks all 4 orthogonal neighbors (up/down/left/right in SCREEN coordinates, not gravity-relative).

Each interaction is specified as:
`IF [this element] is adjacent to [that element] THEN [outcome] WITH [probability per tick]`

#### Interaction Table

|This Element|Adjacent To              |Probability|Outcome                                                                                                                   |
|------------|-------------------------|-----------|--------------------------------------------------------------------------------------------------------------------------|
|Fire        |Wood                     |15% / tick |The Wood cell becomes Fire (lifetime 60).                                                                                 |
|Fire        |Oil                      |40% / tick |The Oil cell becomes Fire (lifetime 60).                                                                                  |
|Fire        |Gunpowder                |80% / tick |The Gunpowder cell becomes Fire (lifetime 20). Additionally, trigger **Explosion** (see below).                           |
|Fire        |Ice                      |10% / tick |The Ice cell becomes Water.                                                                                               |
|Lava        |Wood                     |30% / tick |The Wood cell becomes Fire (lifetime 60).                                                                                 |
|Lava        |Oil                      |50% / tick |The Oil cell becomes Fire (lifetime 60).                                                                                  |
|Lava        |Water                    |100% / tick|The Lava cell becomes Stone. The Water cell becomes Steam (lifetime 180).                                                 |
|Lava        |Ice                      |100% / tick|The Ice cell becomes Water. The Lava cell becomes Stone.                                                                  |
|Acid        |(any non-Acid, non-Empty)|20% / tick |The adjacent cell becomes Empty. The Acid cell has a 10% chance of also becoming Empty (acid is consumed over time).      |
|Steam       |(any cell, on its own)   |0.5% / tick|If lifetime < 60 remaining: the Steam cell becomes Water (condensation). This is a self-check, not a neighbor interaction.|

**Explosion (Gunpowder):**
When gunpowder is ignited, all cells within a circular radius of 6 cells (Euclidean distance ≤ 6.0 from the gunpowder cell’s center) are affected:

- Solid cells within radius: 50% chance of becoming Empty.
- All other non-empty cells within radius: become Fire (lifetime 15).
- Empty cells within radius: 30% chance of becoming Fire (lifetime 15).
  Explosions are processed immediately and can chain (if the explosion radius hits other Gunpowder, those also explode on the same tick).
  **Chain explosion limit:** Maximum 20 chained explosions per tick to prevent freezing.

### 4.5 Color Variation

To avoid a flat, lifeless look, each particle’s rendered color is its base color with a per-particle random brightness offset applied once at creation time.

- On particle creation, generate a random integer in the range [-15, +15].
- Add this value to each of the R, G, B channels of the base color.
- Clamp each channel to [0, 255].
- This color persists for the lifetime of the particle. It does not change per frame.

**Fire special case:** Fire particles cycle their hue over their lifetime. At creation, the color is the base color (`#FF4500`). Over the particle’s lifetime, interpolate linearly toward `#FFD700` (gold/yellow) at the midpoint of life, then toward `#330000` (dark ember) at death. Apply the per-particle brightness offset on top of this interpolated color.

**Lava special case:** Lava particles oscillate brightness sinusoidally. `brightness_offset = sin(current_tick × 0.1 + particle_id × 0.7) × 20`. Apply this in addition to the per-particle random offset.

-----

## 5. Simulation Loop

### 5.1 Tick Rate

The simulation runs at a fixed rate of **60 ticks per second**, decoupled from the rendering frame rate. If rendering drops below 60 FPS, simulation ticks still accumulate and are processed (up to a maximum of 3 ticks per frame to prevent spiral-of-death).

### 5.2 Processing Order

**Within a single tick, particles are processed in scan order relative to the current gravity direction:**

- The row furthest “down” (in gravity direction) is processed first.
- Within each row, columns are processed in a random direction (left-to-right or right-to-left, chosen once per tick per row, 50/50).

**Rationale:** Processing bottom-up (relative to gravity) prevents particles from moving multiple cells per tick. Random lateral ordering prevents systematic left or right bias in liquid/gas spreading.

**Implementation detail:** Each tick, the simulation iterates through all 76,800 cells. Each cell is checked once. A “processed this tick” flag (or equivalent mechanism like a tick counter) prevents a particle that moved into a not-yet-scanned cell from being processed twice in the same tick.

### 5.3 Accelerometer Sampling

The accelerometer is read continuously via the IOKit HID callback mechanism described in the linked repository. The raw X, Y, Z values (divided by 65536 to get g-force) are smoothed using an **exponential moving average with alpha = 0.15**.

The gravity vector for simulation is derived from the X and Y accelerometer axes (the two axes parallel to the laptop’s screen surface):

- **Gravity X component** = smoothed accelerometer X value (left-right tilt)
- **Gravity Y component** = smoothed accelerometer Y value (forward-back tilt)

The gravity vector is normalized to unit length, then scaled by a **gravity strength of 1.0** (meaning: under default gravity, a free-falling particle moves 1 cell per tick in the gravity direction).

**Mapping accelerometer to grid:**

- Accelerometer X positive (right tilt) → particles fall toward higher column indices (screen right)
- Accelerometer X negative (left tilt) → particles fall toward lower column indices (screen left)
- Accelerometer Y positive (tilt away from user) → particles fall toward lower row indices (screen top)
- Accelerometer Y negative (tilt toward user) → particles fall toward higher row indices (screen bottom)

**At rest on a flat surface**, the accelerometer reads approximately (0, 0, -1g) on Z — X and Y are near zero, which means gravity points “down” on screen (toward higher row indices). This is correct default behavior.

**Dead zone:** If the magnitude of the (X, Y) vector is less than 0.05g, snap gravity to straight down (screen direction: toward row 239). This prevents jitter when the laptop is on a flat surface.

**Diagonal gravity:** When gravity is not aligned to a cardinal direction (e.g., tilted 45°), “down” for movement purposes is the nearest cardinal or diagonal direction from the 8 possible directions (N, NE, E, SE, S, SW, W, NW), determined by rounding the gravity angle to the nearest 45° increment.

### 5.4 Gravity Direction → Movement Mapping

The 8 possible gravity directions map to movement axes as follows. “Down” is the gravity direction. “Left-lateral” and “right-lateral” are the two directions perpendicular to down, as seen when facing in the down direction.

|Gravity Direction|“Down” Δ(col, row)|“Down-left” diagonal|“Down-right” diagonal|“Left-lateral”|“Right-lateral”|
|-----------------|------------------|--------------------|---------------------|--------------|---------------|
|S (default)      |(0, +1)           |(-1, +1)            |(+1, +1)             |(-1, 0)       |(+1, 0)        |
|N                |(0, -1)           |(+1, -1)            |(-1, -1)             |(+1, 0)       |(-1, 0)        |
|E                |(+1, 0)           |(+1, +1)            |(+1, -1)             |(0, +1)       |(0, -1)        |
|W                |(-1, 0)           |(-1, -1)            |(-1, +1)             |(0, -1)       |(0, +1)        |
|SE               |(+1, +1)          |(0, +1)             |(+1, 0)              |(-1, +1)      |(+1, -1)       |
|SW               |(-1, +1)          |(-1, 0)             |(0, +1)              |(+1, +1)      |(-1, -1)       |
|NE               |(+1, -1)          |(+1, 0)             |(0, -1)              |(-1, -1)      |(+1, +1)       |
|NW               |(-1, -1)          |(0, -1)             |(-1, 0)              |(+1, -1)      |(-1, +1)       |

-----

## 6. Rendering

### 6.1 Method

Each cell is rendered as a filled square at its grid position. Empty cells are rendered as the background color `#0D0D0D`.

No smoothing, interpolation, or anti-aliasing between cells. The grid should look crisp and pixelated — this is the aesthetic.

### 6.2 Draw Order

Render all cells in a single pass, row by row, top to bottom. No z-ordering or layering between particles. Every non-empty cell draws on top of the background. (Since cells don’t overlap, draw order between particles doesn’t matter.)

### 6.3 Gravity Indicator

A small HUD element in the top-right corner of the canvas shows a circle (diameter: 48 screen pixels, border: 1px `#FFFFFF` at 30% opacity, fill: `#000000` at 50% opacity). Inside the circle, a small filled dot (diameter: 8 screen pixels, color: `#FFFFFF`) shows the current gravity direction. The dot’s position within the circle represents the accelerometer (X, Y) values mapped to the circle’s radius. When gravity is straight down, the dot is at the bottom center of the circle.

-----

## 7. User Input — Drawing

### 7.1 Brush

The user draws particles onto the grid by clicking and dragging with the mouse or trackpad.

- **Left click + drag:** Place particles of the currently selected element.
- **Right click + drag (or Ctrl+click + drag):** Erase — set cells to Empty.

### 7.2 Brush Size

The brush is a filled circle. Brush size is a radius in grid cells.

- **Minimum radius:** 1 (a single cell)
- **Maximum radius:** 20
- **Default radius:** 3
- **Adjustment:** Scroll wheel up/down to increase/decrease radius by 1. Or keyboard `[` to decrease, `]` to increase.

### 7.3 Brush Placement

When drawing, particles are placed in all cells within the brush circle centered at the cursor’s grid position. Only empty cells are filled (the brush does not overwrite existing particles unless erasing).

When dragging, the brush interpolates between the previous and current mouse positions using Bresenham’s line algorithm (or equivalent) to avoid gaps when moving the cursor quickly.

### 7.4 Brush Cursor

A circle outline (1px, white, 50% opacity) is rendered on the canvas at the cursor position showing the current brush size. This is a UI overlay, not part of the simulation.

-----

## 8. User Interface — Toolbar

### 8.1 Layout

The toolbar is a horizontal bar across the top of the window. Height: 48 pixels. Background: `#1A1A1A`. It contains, from left to right:

1. **Element selector buttons** — one per element, in the order listed in the Element Table (Section 4.2).
1. **Spacer** (flexible space)
1. **Action buttons** — Clear, Drain toggle, Pause/Play

### 8.2 Element Buttons

Each element button is a rounded rectangle (corner radius 6px), 36×36 pixels, filled with the element’s base color. A 2px border indicates selection state:

- **Selected:** White border (`#FFFFFF`)
- **Unselected:** No border (or transparent border to maintain layout)

Below (or on top of) each button, the element’s name in 9pt system font, color `#CCCCCC`. Centered under the button.

The currently selected element is Sand on app launch.

**Keyboard shortcuts:** Number keys 1–9 and 0 select elements in order (1=Sand, 2=Water, …, 0=the 10th element). Keys `-` and `=` select the 11th and 12th elements.

### 8.3 Clear Button

Label: “Clear” (or a trash icon). Clicking it removes ALL particles from the grid instantly (all cells become Empty). This requires no confirmation.

**Keyboard shortcut:** `Cmd+Backspace`

### 8.4 Drain Toggle

Label: “Drain” with a toggle/checkbox indicator. When active, the button has a colored indicator (e.g., green dot or highlighted border).

When drain mode is ON: any particle in an edge cell (row 0, row 239, column 0, or column 319) is deleted at the end of each simulation tick.

When drain mode is OFF (default): edge cells are solid walls as described in Section 3.3.

**Keyboard shortcut:** `D`

### 8.5 Pause / Play

Label: “⏸” when running, “▶” when paused. Toggles simulation ticking. When paused:

- The simulation does not advance.
- The user can still draw and erase particles.
- The accelerometer is still read (so the gravity indicator updates).
- Rendering continues (to show drawn changes).

**Keyboard shortcut:** `Space`

-----

## 9. Performance Requirements

### 9.1 Targets

- With ≤30,000 active particles (non-empty cells): maintain 60 FPS render AND 60 ticks/sec simulation on M1 MacBook Air.
- With 30,000–60,000 active particles: maintain ≥30 FPS render, simulation may drop to 30 ticks/sec.
- With >60,000 active particles: best effort. No crash. No freeze exceeding 2 seconds.

### 9.2 Rendering Approach

The recommended approach is to render the grid as a pixel buffer (bitmap) and blit it to the screen each frame. Each cell = 1 pixel in the buffer, then the buffer is scaled up to the canvas size using nearest-neighbor interpolation to maintain the crisp pixel look.

Use Metal, Core Graphics, or equivalent GPU-accelerated drawing. Do NOT use individual NSView/CALayer per cell.

-----

## 10. Accelerometer Access

### 10.1 Privileged Access

The accelerometer requires root/elevated privileges to read via IOKit HID. The app must either:

- **Option A:** Launch with sudo from terminal (acceptable for a portfolio/demo app)
- **Option B:** Use a privileged helper tool (SMJobBless or equivalent) that reads the sensor and communicates values to the main app process via XPC or shared memory

For the initial version, **Option A is acceptable.** Document in the README that the app must be launched with `sudo`.

### 10.2 Fallback

If the accelerometer is not available (not running as root, not on Apple Silicon, or device not found): the app still launches and functions. Gravity defaults to straight down (South) permanently. A small banner at the top of the canvas (below toolbar) displays: “Accelerometer unavailable — running in static gravity mode.” The banner is dismissible by clicking an “×” on its right side.

### 10.3 Sensor Reading

Use the IOKit HID approach from the referenced repository:

- Device: `AppleSPUHIDDevice`, vendor usage page `0xFF00`, usage `3`
- Open with `IOHIDDeviceCreate`
- Register async callback via `IOHIDDeviceRegisterInputReportCallback`
- Parse 22-byte HID reports: X at byte offset 6, Y at byte offset 10, Z at byte offset 14, each as int32 little-endian
- Divide raw values by 65536 to get g-force

-----

## 11. Application Lifecycle

### 11.1 Launch

On launch:

1. Attempt to open the accelerometer (Section 10).
1. Initialize grid to all Empty.
1. Set selected element to Sand.
1. Set drain mode to OFF.
1. Set simulation state to Running (not paused).
1. Begin simulation loop and render loop.

### 11.2 No Persistence

There is no save/load functionality. No preferences are persisted. Closing the app destroys all state. This is intentional — it’s a toy.

### 11.3 Window Close

Closing the window quits the application.

-----

## 12. What This Spec Does NOT Include (Intentional Exclusions)

These features are explicitly out of scope for this spec version:

- Sound effects or audio of any kind
- Undo/redo
- Save/load of grid state
- Export to image or video
- Multiplayer or network features
- Custom element creation
- App Store distribution (this is a direct-download portfolio piece)
- Any analytics, telemetry, or crash reporting
- Light mode / dark mode toggle (the app is dark-mode only as specified)
- Accessibility features beyond keyboard shortcuts
- Localization (English only)
- Touch Bar support
- Menu bar items beyond standard macOS defaults (Close, Quit, Minimize, etc.)

-----

## 13. Test-Specification Guidance

This section provides guidance for writing tests that, combined with this spec, fully encode the program’s intended behavior.

### 13.1 Simulation Tests (unit-level)

These should be pure logic tests with no UI or accelerometer dependency:

- **Powder falling:** Place Sand at (160, 0). Tick once with gravity=South. Assert Sand is at (160, 1).
- **Powder piling:** Place Sand at (160, 239). Tick. Assert Sand remains at (160, 239).
- **Powder sliding:** Fill cells (160, 238) and (160, 239) with Stone. Place Sand at (160, 237). Tick. Assert Sand moved to (159, 238) or (161, 238).
- **Liquid spreading:** Place Water at (160, 239) with Stone floor implicit (row 239 is bottom). Place Water at (160, 238). Tick. Assert Water at (160, 238) moved laterally.
- **Density displacement:** Place Water at (160, 120). Place Sand at (160, 119) (directly above). Tick. Assert Sand is at (160, 120) and Water is at (160, 119) (they swapped).
- **Gravity direction:** Set gravity to East. Place Sand at (0, 120). Tick. Assert Sand is at (1, 120).
- **All 8 gravity directions:** Verify a particle moves in the correct direction for each.
- **Interaction — fire ignites wood:** Place Fire at (160, 120), Wood at (161, 120). Run 200 ticks. Assert Wood cell is no longer Wood (probabilistic; use sufficient ticks for near-certainty).
- **Interaction — lava + water:** Place Lava at (160, 120), Water at (161, 120). Tick once. Assert Lava cell is now Stone and Water cell is now Steam.
- **Interaction — acid dissolves:** Place Acid at (160, 120), Stone at (161, 120). Run 100 ticks. Assert Stone cell is eventually Empty.
- **Explosion:** Place Gunpowder at (160, 120), Fire at (161, 120). Tick. Assert cells within radius 6 are affected per explosion rules.
- **Chain explosion limit:** Place a line of 30 Gunpowder cells. Ignite one end. Assert no more than 20 chain explosions per tick.
- **Gas lifetime:** Create Fire with lifetime 60. Tick 60 times. Assert cell is Empty.
- **Boundary:** Place Sand at (0, 120) with gravity=West. Tick. Assert Sand remains at (0, 120).
- **Drain mode ON:** Enable drain. Place Sand at (0, 120). Tick. Assert cell (0, 120) is Empty.
- **Drain mode OFF:** Disable drain. Place Sand at (0, 120) with gravity=West. Tick. Assert Sand remains at (0, 120).
- **Pause:** Set paused. Place Sand at (160, 0). Tick (should be no-op). Assert Sand still at (160, 0).
- **Liquid spread rate:** Place Water on a flat surface. Tick once. Assert it moved at most 3 cells laterally.
- **No double-processing:** Place Sand at (160, 0) with gravity=South. Tick once. Assert Sand is at (160, 1), NOT (160, 2).

### 13.2 Accelerometer Tests

- **Smoothing:** Feed raw values [0, 0, 1.0, 0, 0, …] then abruptly [0.5, 0, …]. Assert smoothed value approaches 0.5 at the rate defined by alpha=0.15.
- **Dead zone:** Feed (X=0.03, Y=0.02). Assert gravity direction resolves to South.
- **Direction mapping:** Feed (X=1.0, Y=0). Assert gravity direction is East. Feed (X=0, Y=-1.0). Assert gravity is South. Test all 8 directions.

### 13.3 UI Tests

- **Element selection:** Click Sand button. Assert selected element is Sand. Press key ‘2’. Assert selected element is Water.
- **Brush size:** Scroll up 3 times from default (3). Assert brush radius is 6. Scroll down 10 times. Assert brush radius is 1 (minimum).
- **Drawing:** Click at grid position (160, 120) with Sand selected and brush radius 1. Assert cell (160, 120) is Sand.
- **Erasing:** Place Sand at (160, 120). Right-click at (160, 120) with brush radius 1. Assert cell is Empty.
- **Clear:** Fill 100 random cells. Press Cmd+Backspace. Assert all cells are Empty.
- **Draw does not overwrite:** Place Stone at (160, 120). Left-click at (160, 120) with Sand selected. Assert cell is still Stone.

### 13.4 Rendering Tests

- **Color variation range:** Create 1000 Sand particles. Assert all rendered colors have R, G, B within ±15 of Sand’s base color channels.
- **Fire color interpolation:** Create Fire. At tick 0, assert color is near `#FF4500`. At tick 30 (midlife), assert color is near `#FFD700`. At tick 59 (near death), assert color is near `#330000`.
- **Empty cell color:** Assert empty cells render as `#0D0D0D`.
- **Gravity indicator position:** Set gravity=South. Assert indicator dot is at bottom center of indicator circle. Set gravity=East. Assert dot is at right center.

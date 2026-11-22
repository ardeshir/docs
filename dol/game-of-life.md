# Conway’s Game of Life

A perfect fit for DOL Spirits. 

> **Status (verified against DOL v0.8.2, 2026-11-20):** The DOL source in this walkthrough parses
> with DOL 0.8.2. The DOL → Rust → WASM → browser pipeline in Step 7 is **not working end-to-end**:
> there is no `dol build` command, and the real `dol-build` tool (Spirit → Rust → wasm32) fails on all
> nine example Spirits in the dol repository at v0.8.2. Treat Step 7 as **Planned — not implemented**.
> The generated Rust shown in Step 7c is illustrative, not actual compiler output.
> A version of this Spirit lives in the dol repository under `examples/spirits/game-of-life/`.

## Step 1: Understanding the Rules

The four rules are:

|Cell State|Neighbors|Result               |
|----------|---------|---------------------|
|**Alive** |0-1      |Dies (solitude)      |
|**Alive** |2-3      |Survives             |
|**Alive** |4+       |Dies (overpopulation)|
|**Dead**  |3        |Becomes alive        |

## Step 2: Design the DOL Ontology

Let’s start with the core types:

`Spirit.dol` manifests are read by a separate manifest parser (`src/manifest.rs`), not the DOL source
parser. This is the manifest from `examples/spirits/game-of-life/Spirit.dol` in the dol repository:

```text
// Spirit.dol - Package manifest
spirit game_of_life @ 0.1.0

docs "Conway's Game of Life as a DOL Spirit. Cellular automaton with B3/S23 rules."

requires {
    @univrs/std: "^0.8"
}

targets {
    rust: { edition: "2024" }
    wasm: { optimize: true, target: "wasm32-unknown-unknown" }
}

config {
    entry: "src/lib.dol"
    target: wasm32
    features: []
}
```

```dol
// src/genes/cell.dol
mod genes.cell

pub gen CellState {
  type: enum { Dead, Alive }
  
  docs { The binary state of a cell in the grid. }
}

pub gen Position {
  has x: i32
  has y: i32
  
  rule valid_coords {
    this.x >= 0 && this.y >= 0
  }
  
  docs { A coordinate position on the grid. }
}

pub gen Cell {
  has pos: Position
  has state: CellState
  has neighbors: u8
  
  rule valid_neighbor_count {
    this.neighbors <= 8
  }
  
  docs { 
    A single cell in the Game of Life grid.
    Tracks position, current state, and neighbor count.
  }
}
```

```dol
// src/genes/grid.dol
mod genes.grid

use genes.cell.{ Cell, CellState, Position }

pub gen Grid {
  has width: u32
  has height: u32
  has cells: Vec<Cell>
  has generation: u64
  
  rule valid_dimensions {
    this.width > 0 && this.height > 0
  }
  
  rule cell_count_matches {
    this.cells.len() == (this.width * this.height) as u64
  }
  
  docs {
    The game board - a 2D grid of cells.
    Tracks dimensions, cell states, and generation count.
  }
}

pub gen GridConfig {
  has width: u32
  has height: u32
  has wrap_edges: bool
  
  rule reasonable_size {
    this.width <= 1000 && this.height <= 1000
  }
  
  docs {
    Configuration for creating a new grid.
    wrap_edges enables toroidal topology (edges connect).
  }
}
```

> **Note (v0.8.2):** the parser accepts `rule` blocks nested inside a `gen` and `pub` modifiers, but drops them from the AST (nested rule bodies are discarded; visibility is always recorded as private). They are not enforced.

## Step 3: Implement the Rules as Spells

```dol
// src/spells/rules.dol
mod spells.rules

use genes.cell.{ Cell, CellState }

// The four rules of Conway's Game of Life
pub fun next_state(cell: Cell) -> CellState {
  match cell.state {
    CellState.Alive {
      match cell.neighbors {
        n if n < 2 { CellState.Dead }      // Solitude
        n if n > 3 { CellState.Dead }      // Overpopulation  
        _ { CellState.Alive }                  // Survives (2-3)
      }
    }
    CellState.Dead {
      match cell.neighbors {
        3 { CellState.Alive }                  // Reproduction
        _ { CellState.Dead }
      }
    }
  }
}

// Alternative: Condensed rule using B3/S23 notation
pub fun apply_b3s23(alive: bool, neighbors: u8) -> bool {
  if alive {
    neighbors == 2 || neighbors == 3
  } else {
    neighbors == 3
  }
}

docs {
  Conway's Game of Life follows the B3/S23 rule:
  - Birth: Dead cell with exactly 3 neighbors becomes alive
  - Survival: Live cell with 2 or 3 neighbors survives
}
```

## Step 4: Grid Operations

```dol
// src/spells/grid_ops.dol
mod spells.grid_ops

use genes.cell.{ Cell, CellState, Position }
use genes.grid.{ Grid, GridConfig }
use spells.rules.next_state

// Create empty grid
pub fun create_grid(config: GridConfig) -> Grid {
  val cells = Vec.new()
  
  for y in 0..config.height {
    for x in 0..config.width {
      cells.push(Cell {
        pos: Position { x: x as i32, y: y as i32 },
        state: CellState.Dead,
        neighbors: 0
      })
    }
  }
  
  Grid {
    width: config.width,
    height: config.height,
    cells: cells,
    generation: 0
  }
}

// Get cell at position (with optional wrapping)
pub fun get_cell(grid: Grid, x: i32, y: i32, wrap: bool) -> Option<Cell> {
  val actual_x = if wrap { 
    ((x % grid.width as i32) + grid.width as i32) % grid.width as i32 
  } else { x }
  
  val actual_y = if wrap {
    ((y % grid.height as i32) + grid.height as i32) % grid.height as i32
  } else { y }
  
  if actual_x < 0 || actual_x >= grid.width as i32 ||
     actual_y < 0 || actual_y >= grid.height as i32 {
    return None
  }
  
  val idx = (actual_y as u32 * grid.width + actual_x as u32) as u64
  Some(grid.cells[idx])
}

// Count alive neighbors for a cell
pub fun count_neighbors(grid: Grid, pos: Position, wrap: bool) -> u8 {
  var count: u8 = 0
  
  for dy in -1..2 {
    for dx in -1..2 {
      if dx != 0 || dy != 0 {
        match get_cell(grid, pos.x + dx, pos.y + dy, wrap) {
          Some(cell) if cell.state == CellState.Alive {
            count = count + 1
          }
          _ { }
        }
      }
    }
  }
  
  count
}

// Advance grid by one generation
pub fun tick(grid: Grid, wrap: bool) -> Grid {
  // First pass: count all neighbors
  val cells_with_neighbors = grid.cells 
    |> map(|cell: Cell| Cell {
      pos: cell.pos,
      state: cell.state,
      neighbors: count_neighbors(grid, cell.pos, wrap)
    })
  
  // Second pass: apply rules
  val next_cells = cells_with_neighbors
    |> map(|cell: Cell| Cell {
      pos: cell.pos,
      state: next_state(cell),
      neighbors: 0  // Will be recalculated next tick
    })
  
  Grid {
    width: grid.width,
    height: grid.height,
    cells: next_cells,
    generation: grid.generation + 1
  }
}

docs {
  Grid operations for the Game of Life.
  Supports both bounded and toroidal (wrapping) grids.
}
```

## Step 5: Pattern Loading (Famous Patterns)

```dol
// src/spells/patterns.dol
mod spells.patterns

use genes.cell.{ CellState, Position }
use genes.grid.Grid
use spells.grid_ops.{ create_grid, set_cell }

pub gen Pattern {
  has name: string
  has cells: Vec<Position>
  has width: u32
  has height: u32
  
  docs { A predefined Game of Life pattern. }
}

// Classic patterns
pub fun glider() -> Pattern {
  Pattern {
    name: "Glider",
    cells: [
      Position { x: 1, y: 0 },
      Position { x: 2, y: 1 },
      Position { x: 0, y: 2 },
      Position { x: 1, y: 2 },
      Position { x: 2, y: 2 }
    ],
    width: 3,
    height: 3
  }
}

pub fun blinker() -> Pattern {
  Pattern {
    name: "Blinker",
    cells: [
      Position { x: 0, y: 1 },
      Position { x: 1, y: 1 },
      Position { x: 2, y: 1 }
    ],
    width: 3,
    height: 3
  }
}

pub fun block() -> Pattern {
  Pattern {
    name: "Block",
    cells: [
      Position { x: 0, y: 0 },
      Position { x: 1, y: 0 },
      Position { x: 0, y: 1 },
      Position { x: 1, y: 1 }
    ],
    width: 2,
    height: 2
  }
}

pub fun gosper_glider_gun() -> Pattern {
  Pattern {
    name: "Gosper Glider Gun",
    cells: [
      // Left square
      Position { x: 0, y: 4 }, Position { x: 0, y: 5 },
      Position { x: 1, y: 4 }, Position { x: 1, y: 5 },
      // Left part of gun
      Position { x: 10, y: 4 }, Position { x: 10, y: 5 }, Position { x: 10, y: 6 },
      Position { x: 11, y: 3 }, Position { x: 11, y: 7 },
      Position { x: 12, y: 2 }, Position { x: 12, y: 8 },
      Position { x: 13, y: 2 }, Position { x: 13, y: 8 },
      Position { x: 14, y: 5 },
      Position { x: 15, y: 3 }, Position { x: 15, y: 7 },
      Position { x: 16, y: 4 }, Position { x: 16, y: 5 }, Position { x: 16, y: 6 },
      Position { x: 17, y: 5 },
      // Right part of gun
      Position { x: 20, y: 2 }, Position { x: 20, y: 3 }, Position { x: 20, y: 4 },
      Position { x: 21, y: 2 }, Position { x: 21, y: 3 }, Position { x: 21, y: 4 },
      Position { x: 22, y: 1 }, Position { x: 22, y: 5 },
      Position { x: 24, y: 0 }, Position { x: 24, y: 1 },
      Position { x: 24, y: 5 }, Position { x: 24, y: 6 },
      // Right square
      Position { x: 34, y: 2 }, Position { x: 34, y: 3 },
      Position { x: 35, y: 2 }, Position { x: 35, y: 3 }
    ],
    width: 36,
    height: 9
  }
}

// Place pattern on grid at offset
pub fun place_pattern(grid: Grid, pattern: Pattern, offset_x: i32, offset_y: i32) -> Grid {
  var result = grid
  
  for pos in pattern.cells {
    result = set_cell(result, 
      pos.x + offset_x, 
      pos.y + offset_y, 
      CellState.Alive
    )
  }
  
  result
}

docs {
  Classic Game of Life patterns.
  - Glider: Moves diagonally across the grid
  - Blinker: Oscillates with period 2
  - Block: Still life (stable)
  - Gosper Glider Gun: Produces gliders infinitely
}
```

## Step 6: Browser Bindings (WASM Interface)

```dol
// src/sex/browser.dol
mod sex.browser

use genes.grid.{ Grid, GridConfig }
use spells.grid_ops.{ create_grid, tick }
use spells.patterns.{ glider, gosper_glider_gun, place_pattern }

// Exported state (WASM-accessible)
sex var GRID: Option<Grid> = None
sex var CONFIG: GridConfig = GridConfig { 
  width: 100, 
  height: 100, 
  wrap_edges: true 
}

// Initialize the game
pub sex fun init(width: u32, height: u32, wrap: bool) {
  CONFIG = GridConfig { width: width, height: height, wrap_edges: wrap }
  GRID = Some(create_grid(CONFIG))
}

// Advance one generation
pub sex fun step() -> u64 {
  match GRID {
    Some(grid) {
      GRID = Some(tick(grid, CONFIG.wrap_edges))
      GRID.unwrap().generation
    }
    None { 0 }
  }
}

// Set cell state (for user interaction)
pub sex fun set_cell_state(x: i32, y: i32, alive: bool) {
  match GRID {
    Some(grid) {
      GRID = Some(set_cell(grid, x, y, 
        if alive { CellState.Alive } else { CellState.Dead }
      ))
    }
    None { }
  }
}

// Load a pattern
pub sex fun load_pattern(name: string, x: i32, y: i32) {
  match GRID {
    Some(grid) {
      val pattern = match name {
        "glider" { glider() }
        "gun" { gosper_glider_gun() }
        _ { glider() }
      }
      GRID = Some(place_pattern(grid, pattern, x, y))
    }
    None { }
  }
}

// Get grid state as flat array for rendering
pub sex fun get_cells() -> Vec<u8> {
  match GRID {
    Some(grid) {
      grid.cells |> map(|cell: Cell| 
        if cell.state == CellState.Alive { 1 } else { 0 }
      )
    }
    None { [] }
  }
}

// Get current generation
pub sex fun get_generation() -> u64 {
  match GRID {
    Some(grid) { grid.generation }
    None { 0 }
  }
}

docs {
  Browser bindings for the Game of Life Spirit.
  These functions are exported to WASM and callable from JavaScript.
}
```

## Step 7: Compilation Pipeline

Now let’s show the intended pipeline from DOL → Rust → WASM → Browser.

> **Planned — not implemented:** at DOL v0.8.2 this pipeline does not complete. `dol build` does not exist; the real tool is `dol-build` (installed with `cargo install dol --features cli`), and it fails on all nine example Spirits in the dol repository.

### 7a. Project Structure

```
game-of-life/
├── Spirit.dol              # Package manifest
├── src/
│   ├── lib.dol             # Library exports
│   ├── genes/
│   │   ├── cell.dol
│   │   └── grid.dol
│   ├── spells/
│   │   ├── rules.dol
│   │   ├── grid_ops.dol
│   │   └── patterns.dol
│   └── sex/
│       └── browser.dol     # WASM bindings
├── web/
│   ├── index.html
│   ├── game.js
│   └── style.css
└── target/
    ├── rust/               # Generated Rust
    └── wasm/               # Compiled WASM
```

### 7b. Compile DOL → Rust

```bash
# Step 1: Compile DOL to Rust
cd game-of-life
dol-build .   # Planned — not working at v0.8.2 (there is no `dol build` command)

# Intended output:
# target/rust/
# ├── Cargo.toml
# ├── src/
# │   ├── lib.rs
# │   ├── genes/
# │   │   ├── mod.rs
# │   │   ├── cell.rs
# │   │   └── grid.rs
# │   ├── spells/
# │   │   ├── mod.rs
# │   │   ├── rules.rs
# │   │   ├── grid_ops.rs
# │   │   └── patterns.rs
# │   └── browser.rs        # WASM exports
```

### 7c. Generated Rust Code (Illustrative)

> Hand-written illustration of the intended output; not actual `dol-codegen` / `dol-build` output.

```rust
// target/rust/src/genes/cell.rs
// Illustrative only (not actual compiler output)

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CellState {
    Dead,
    Alive,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Position {
    pub x: i32,
    pub y: i32,
}

impl Position {
    pub fn validate(&self) -> bool {
        self.x >= 0 && self.y >= 0
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Cell {
    pub pos: Position,
    pub state: CellState,
    pub neighbors: u8,
}

impl Cell {
    pub fn validate(&self) -> bool {
        self.neighbors <= 8
    }
}
```

```rust
// target/rust/src/spells/rules.rs
// Illustrative only (not actual compiler output)

use crate::genes::cell::{Cell, CellState};

/// Conway's Game of Life rules (B3/S23)
pub fn next_state(cell: &Cell) -> CellState {
    match cell.state {
        CellState::Alive => match cell.neighbors {
            0..=1 => CellState::Dead,  // Solitude
            2..=3 => CellState::Alive, // Survives
            _ => CellState::Dead,      // Overpopulation
        },
        CellState::Dead => match cell.neighbors {
            3 => CellState::Alive,     // Reproduction
            _ => CellState::Dead,
        },
    }
}
```

```rust
// target/rust/src/browser.rs
// Illustrative only (not actual compiler output)

use wasm_bindgen::prelude::*;
use crate::genes::grid::{Grid, GridConfig};
use crate::spells::grid_ops::{create_grid, tick};

static mut GRID: Option<Grid> = None;
static mut CONFIG: GridConfig = GridConfig {
    width: 100,
    height: 100,
    wrap_edges: true,
};

#[wasm_bindgen]
pub fn init(width: u32, height: u32, wrap: bool) {
    unsafe {
        CONFIG = GridConfig { width, height, wrap_edges: wrap };
        GRID = Some(create_grid(&CONFIG));
    }
}

#[wasm_bindgen]
pub fn step() -> u64 {
    unsafe {
        if let Some(ref grid) = GRID {
            let next = tick(grid, CONFIG.wrap_edges);
            let gen = next.generation;
            GRID = Some(next);
            gen
        } else {
            0
        }
    }
}

#[wasm_bindgen]
pub fn get_cells() -> Vec<u8> {
    unsafe {
        match &GRID {
            Some(grid) => grid.cells.iter()
                .map(|c| if c.state == CellState::Alive { 1 } else { 0 })
                .collect(),
            None => vec![],
        }
    }
}

#[wasm_bindgen]
pub fn get_generation() -> u64 {
    unsafe {
        GRID.as_ref().map(|g| g.generation).unwrap_or(0)
    }
}
```

### 7d. Compile Rust → WASM

```bash
# Step 2: Build WASM from generated Rust
cd target/rust

cargo build --target wasm32-unknown-unknown --release

# Step 3: Generate JS bindings
wasm-bindgen target/wasm32-unknown-unknown/release/game_of_life.wasm \
  --out-dir ../wasm \
  --target web

# Output:
# target/wasm/
# ├── game_of_life.js      # JS bindings
# ├── game_of_life.d.ts    # TypeScript types
# └── game_of_life_bg.wasm # WASM binary
```

### 7e. HTML/JavaScript Frontend

```html
<!-- web/index.html -->
<!DOCTYPE html>
<html>
<head>
  <title>Game of Life Spirit</title>
  <style>
    body { 
      background: #1a1a2e; 
      color: #eee;
      font-family: system-ui;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px;
    }
    canvas { 
      border: 2px solid #4a4a6a;
      cursor: crosshair;
    }
    .controls {
      margin: 20px 0;
      display: flex;
      gap: 10px;
    }
    button {
      background: #4a4a6a;
      color: white;
      border: none;
      padding: 10px 20px;
      cursor: pointer;
      border-radius: 4px;
    }
    button:hover { background: #6a6a8a; }
    .info { color: #888; margin-top: 10px; }
  </style>
</head>
<body>
  <h1>🎮 Game of Life Spirit</h1>
  <div class="controls">
    <button id="start">▶ Start</button>
    <button id="stop">⏹ Stop</button>
    <button id="step">⏭ Step</button>
    <button id="clear">🗑 Clear</button>
    <button id="glider">🚀 Glider</button>
    <button id="gun">🔫 Glider Gun</button>
  </div>
  <canvas id="canvas" width="800" height="800"></canvas>
  <div class="info">
    Generation: <span id="gen">0</span> | 
    Click to toggle cells | 
    Powered by DOL Spirit
  </div>

  <script type="module">
    import init, { 
      init as gameInit, 
      step, 
      get_cells, 
      get_generation,
      set_cell_state,
      load_pattern 
    } from './game_of_life.js';

    const GRID_SIZE = 100;
    const CELL_SIZE = 8;
    
    let running = false;
    let animationId = null;

    async function main() {
      // Initialize WASM module
      await init();
      
      // Initialize game grid
      gameInit(GRID_SIZE, GRID_SIZE, true);
      
      const canvas = document.getElementById('canvas');
      const ctx = canvas.getContext('2d');
      
      // Render function
      function render() {
        const cells = get_cells();
        ctx.fillStyle = '#1a1a2e';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        ctx.fillStyle = '#00ff88';
        for (let i = 0; i < cells.length; i++) {
          if (cells[i] === 1) {
            const x = (i % GRID_SIZE) * CELL_SIZE;
            const y = Math.floor(i / GRID_SIZE) * CELL_SIZE;
            ctx.fillRect(x, y, CELL_SIZE - 1, CELL_SIZE - 1);
          }
        }
        
        document.getElementById('gen').textContent = get_generation();
      }
      
      // Game loop
      function gameLoop() {
        if (running) {
          step();
          render();
          animationId = requestAnimationFrame(gameLoop);
        }
      }
      
      // Event handlers
      document.getElementById('start').onclick = () => {
        running = true;
        gameLoop();
      };
      
      document.getElementById('stop').onclick = () => {
        running = false;
        if (animationId) cancelAnimationFrame(animationId);
      };
      
      document.getElementById('step').onclick = () => {
        step();
        render();
      };
      
      document.getElementById('clear').onclick = () => {
        gameInit(GRID_SIZE, GRID_SIZE, true);
        render();
      };
      
      document.getElementById('glider').onclick = () => {
        load_pattern("glider", 10, 10);
        render();
      };
      
      document.getElementById('gun').onclick = () => {
        load_pattern("gun", 10, 30);
        render();
      };
      
      // Click to toggle cells
      canvas.onclick = (e) => {
        const rect = canvas.getBoundingClientRect();
        const x = Math.floor((e.clientX - rect.left) / CELL_SIZE);
        const y = Math.floor((e.clientY - rect.top) / CELL_SIZE);
        set_cell_state(x, y, true);
        render();
      };
      
      // Initial render
      render();
    }
    
    main();
  </script>
</body>
</html>
```

### 7f. One-Command Build Script

```bash
#!/bin/bash
# build.sh - Complete DOL → Browser pipeline

set -e

echo "🔮 Building Game of Life Spirit..."

# Step 1: DOL → Rust
echo "📝 Compiling DOL to Rust..."
# Planned — not working at v0.8.2: there is no `dol build` command
dol build --target rust src/ -o target/rust/

# Step 2: Rust → WASM  
echo "⚙️  Compiling Rust to WASM..."
cd target/rust
cargo build --target wasm32-unknown-unknown --release

# Step 3: Generate JS bindings
echo "🔗 Generating JavaScript bindings..."
wasm-bindgen target/wasm32-unknown-unknown/release/game_of_life.wasm \
  --out-dir ../../web \
  --target web

cd ../..

# Step 4: Optimize WASM (optional)
echo "🚀 Optimizing WASM..."
wasm-opt -O3 web/game_of_life_bg.wasm -o web/game_of_life_bg.wasm

echo "✅ Build complete! Open web/index.html in a browser."
```

## Summary: The Full Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    DOL Spirit Pipeline                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌─────────┐ │
│   │   DOL    │ -> │   Rust   │ -> │   WASM   │ -> │ Browser │ │
│   │  Source  │    │   Code   │    │  Binary  │    │   App   │ │
│   └──────────┘    └──────────┘    └──────────┘    └─────────┘ │
│                                                                 │
│   • genes/        • structs       • wasm-bindgen   • Canvas    │
│   • spells/       • functions     • JS bindings    • Controls  │
│   • sex/          • wasm_bindgen  • TypeScript     • Animation │
│                     exports         types                       │
│                                                                 │
│   Commands:                                                     │
│   1. (planned) DOL → Rust: no working command at v0.8.2        │
│   2. cargo build --target wasm32-unknown-unknown --release     │
│   3. wasm-bindgen ... --target web                             │
│   4. Open index.html                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

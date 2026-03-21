# AWR - Agent World Runtime

**A new compute substrate: State → Simulate → Evaluate → Commit**

AWR is an open-source, local-first, hardware-agnostic world runtime for AI. Instead of symbolic reasoning (`Thought → Action → Result`), AWR uses physics as reasoning:

```
Traditional AI:  Thought → Action → Result
AWR:             State → Simulate → Evaluate → Commit
```

LLMs fail because they don't have a world to think inside. They discuss physics without understanding physics, describe spatial relationships without perceiving space, reason about causation without experiencing cause and effect. AWR provides that world.

## Features

- **CPU-only** - No GPU required, runs on any hardware with Godot 4.2+
- **Deterministic** - Same input always produces same output
- **Fast** - 519+ branches/second for parallel world simulation
- **Open-source** - MIT licensed, no cloud dependency
- **Local-first** - Everything runs on your machine

## Installation

1. Copy the `addons/awr/` folder to your Godot project's `addons/` directory
2. Enable the plugin in Project → Project Settings → Plugins
3. AWR autoloads as `AWR` singleton

## Quick Start

```gdscript
# Create a world with a ball and goal
var world = AWR.create_world({
    "bounds": {"x": 0, "y": 0, "width": 1000, "height": 600},
    "bodies": [
        {"id": "ball", "pos": [100, 300], "radius": 15, "mass": 1.0},
        {"id": "goal", "pos": [900, 300], "radius": 30, "static": true}
    ]
})

# Define action space (possible impulses)
var actions = []
for vx in range(-20, 21, 5):
    for vy in range(-20, 21, 5):
        actions.append({
            "type": "apply_impulse",
            "target": "ball",
            "params": {"x": vx, "y": vy}
        })

# Simulate all branches and find best action
var result = AWR.simulate_best(world, actions, {
    "horizon": 120,  # 2 seconds at 60fps
    "evaluator": func(state):
        return Evaluator.goal_distance(state, "ball", Vector2(900, 300))
})

print("Best action: ", result.action)
print("Score: ", result.score)
```

## The 6 Primitives

### 1. WorldState
Persistent scene graph - the **memory** of the world. Every node is a fact.

```gdscript
var state = WorldState.from_config({
    "bounds": {"x": 0, "y": 0, "width": 1000, "height": 1000},
    "bodies": [
        {"id": "player", "pos": [50, 50], "vel": [0, 0], "mass": 1.0}
    ]
})

state.apply({"type": "apply_impulse", "target": "player", "params": {"x": 10, "y": 0}})
state.step(1.0/60.0)
var snapshot = state.clone()
```

### 2. SimLoop ⭐ (Core Primitive)
Branching simulation that clones state, applies hypothetical actions, advances time, scores outcomes.

```gdscript
var sim = SimLoop.new(world, eval_func)
var result = sim.search_best(action_space)
# Or get all results sorted by score
var all_results = sim.search_all(action_space)
```

### 3. Evaluator
Scoring functions for branch comparison. Higher score = better outcome.

```gdscript
# Built-in evaluators
Evaluator.goal_distance(state, "ball", target_pos)  # Closer = higher score
Evaluator.collision_free(state)                      # No collisions = 0
Evaluator.energy_efficient(state)                    # Less movement = higher
Evaluator.combined(state, {"goal": 1.0, "collision": 0.5, "energy": 0.1})

# Create callable evaluators
var eval = Evaluator.make_goal_evaluator("ball", Vector2(900, 300))
```

### 4. CausalBus
Traceable event system. Every change linked to its cause.

```gdscript
CausalBus.emit("body_moved", {"body_id": "ball", "from": old_pos, "to": new_pos})
CausalBus.emit("collision", {"body_a": "ball", "body_b": "wall", "point": contact})
```

### 5. Collision2D
2D rigid body collision detection and response.

```gdscript
# Automatically integrated into WorldState.step()
# Supports circle-circle collisions with elastic response
```

### 6. PerceptionLayer
Viewport capture → VLM → WorldState update (requires MCP integration).

## API Reference

### AWR Autoload

| Method | Description |
|--------|-------------|
| `create_world(config: Dictionary) -> WorldState` | Create world from config |
| `simulate_best(world, actions, options) -> Dictionary` | Find best action |
| `simulate_all(world, actions, options) -> Array` | Get all results sorted |

### WorldState

| Method | Description |
|--------|-------------|
| `clone() -> WorldState` | Deep copy of state |
| `apply(action: Dictionary)` | Apply action to state |
| `step(dt: float)` | Advance simulation by dt seconds |
| `hash() -> int` | Hash for branch comparison |
| `get_body(id: String) -> Dictionary` | Get body by ID |
| `has_body(id: String) -> bool` | Check if body exists |
| `add_body(body: Dictionary)` | Add new body |
| `from_config(config: Dictionary) -> WorldState` | Static factory |

### Action Types

```gdscript
{"type": "move", "target": "id", "params": {"x": 10, "y": 0}}
{"type": "set_position", "target": "id", "params": {"x": 100, "y": 200}}
{"type": "apply_force", "target": "id", "params": {"x": 5, "y": 0}}
{"type": "apply_impulse", "target": "id", "params": {"x": 10, "y": 5}}
{"type": "set_velocity", "target": "id", "params": {"x": 0, "y": 0}}
{"type": "spawn", "params": {"id": "new", "pos": [50, 50], ...}}
{"type": "destroy", "target": "id"}
{"type": "set_bounds", "params": {"x": 0, "y": 0, "width": 1000, "height": 600}}
```

### Body Structure

```gdscript
{
    "id": "ball",           # Unique identifier
    "pos": {"x": 100, "y": 200},  # Position (or [100, 200])
    "vel": {"x": 0, "y": 0},      # Velocity
    "force": {"x": 0, "y": 0},    # Accumulated force
    "mass": 1.0,            # Mass in kg
    "radius": 10.0,         # Collision radius
    "restitution": 0.8,     # Bounciness (0-1)
    "static": false         # Immovable if true
}
```

## Running Tests

```bash
# Run all tests
godot --headless --path godot-test-project -s addons/awr/tests/run_all_tests.gd

# Run specific test suite
godot --headless --path godot-test-project -s addons/awr/tests/test_sim_loop.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_collision.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_gravity_slingshot.gd
```

## Performance

| Metric | Value |
|--------|-------|
| Branches/second | ~519 (CPU-only) |
| Latency per branch | ~1.93ms |
| Test coverage | 43 tests passing |
| Determinism | 100% verified |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWR Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ Perception   │───▶│  WorldState  │◀───│  WorldGen    │      │
│  │    Layer     │    │  (SceneGraph)│    │  (3D Gen)    │      │
│  └──────────────┘    └──────┬───────┘    └──────────────┘      │
│                             │                                   │
│                             ▼                                   │
│                      ┌──────────────┐                          │
│                      │   SimLoop    │ ◀── Core Primitive       │
│                      │ (Branching)  │                          │
│                      └──────┬───────┘                          │
│                             │                                   │
│                             ▼                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  RealBridge  │◀───│  CausalBus   │───▶│   Agent      │      │
│  │ (DigitalTwin)│    │   (Events)   │    │  Interface   │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Comparison

| Project | Funding | Hardware | Open Source |
|---------|---------|----------|-------------|
| World Labs | $230M+ | GPU/Cloud | No |
| NVIDIA Cosmos | Billions | NVIDIA GPU | Partial |
| MuJoCo | Acquired | CPU/GPU | Yes |
| **AWR** | **$0** | **CPU-only** | **Yes** |

## What AWR Enables

- **Planning engine** - Multi-step action planning via branch search
- **Robotics brain** - Simulate before acting in the real world
- **Game AI** - Enemies that "think" by simulating futures
- **Digital twins** - Sync simulation with real hardware via MQTT

## License

MIT

## Credits

AWR is inspired by research in:
- Cognitive maps (O'Keefe, Moser & Moser - Nobel Prize 2014)
- World models (Ha & Schmidhuber 2018, LeCun's JEPA)
- Embodied cognition (Varela, Thompson, Rosch 1991)

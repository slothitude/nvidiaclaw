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
- **Spatial Memory** - v0.2 introduces the first AI memory system based on cognitive maps
- **AGI Patterns** - v0.3 adds complete cognitive architecture (BDI, Global Workspace, HTN, etc.)

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

---

## v0.2: Spatial Memory Engine

**The first AI memory system based on cognitive maps.**

Based on:
- **Method of Loci** (Memory Palace) - 2000+ year old technique
- **Cognitive Maps** - Nobel Prize 2014 (O'Keefe, Moser & Moser)

The key insight: "The nothing that surrounds objects IS the memory structure."

| Current AI Memory | Spatial Memory (AWR) |
|-------------------|----------------------|
| Vector embeddings (abstract) | Physical locations (concrete) |
| Similarity = cosine distance | Similarity = spatial distance |
| Retrieval = search | Retrieval = navigation |
| Static storage | Active simulation |
| Token sequences | 3D coordinates |

### Quick Start: Spatial Memory

```gdscript
# Store concepts at spatial locations
AWR.memorize("machine_learning", Vector3(0, 0, 0))
AWR.memorize("neural_networks", Vector3(50, 0, 0))
AWR.memorize("deep_learning", Vector3(53, 0, 2))
AWR.memorize("gradients", Vector3(50, 0, 5))

# Find the path between concepts (THIS IS REASONING!)
var path = AWR.spatial_reason("machine_learning", "neural_networks")
print("Distance: ", path.distance)  # Semantic distance

# Get concepts along the path (THE ANSWER!)
var concepts = AWR.concepts_on_path(path)
print("Relationship: ", concepts)  # ["deep_learning", "gradients", ...]

# Semantic distance between concepts
var dist = AWR.semantic_distance("machine_learning", "deep_learning")
print("Relatedness: ", dist)  # Lower = more related
```

### Building a Memory Palace

```gdscript
# Auto-build from concept list
var concepts: Array[Dictionary] = [
    {"name": "machine_learning", "tags": ["ai", "data"]},
    {"name": "neural_networks", "tags": ["ai", "deep_learning"]},
    {"name": "statistics", "tags": ["math", "data"]},
    {"name": "biology", "tags": ["science", "life"]},
]
AWR.build_palace(concepts)

# Build linear palace (for sequences/stories)
var steps: Array[String] = ["step1", "step2", "step3", "step4"]
AWR.build_linear_palace(steps)

# Build spiral palace (for exploration)
var topics: Array[String] = ["intro", "basics", "advanced", "expert"]
AWR.build_spiral_palace(topics)
```

### Spatial Memory API

| Method | Description |
|--------|-------------|
| `memorize(concept, location, metadata)` | Store concept at location |
| `recall(location)` | Retrieve by location |
| `recall_by_concept(name)` | Retrieve by concept name |
| `spatial_reason(from, to)` | Find path between concepts |
| `concepts_on_path(path)` | Get concepts along path |
| `semantic_distance(a, b)` | Physical distance = semantic distance |
| `concept_neighbors(concept, radius)` | Find nearby concepts |
| `build_palace(concepts)` | Auto-organize concepts into rooms |
| `save_memory(path)` | Persist to file |
| `load_memory(path)` | Load from file |

---

## v0.3: AGI Patterns (Meeseeks Integration)

**The first game engine with built-in AGI patterns.**

AWR now includes a complete cognitive architecture based on proven AGI research:

| Pattern | Purpose | Source |
|---------|---------|--------|
| **BDI Model** | Beliefs-Desires-Intentions for goal tracking | Rao & Georgeff |
| **Global Workspace** | Attention/consciousness via competition | Baars |
| **HTN Planner** | Hierarchical task decomposition | Nau et al. |
| **Memory-Prediction** | Learning from prediction errors | Hawkins |
| **Self-Improvement** | Performance tracking & strategy generation | Meeseeks AGI |
| **The Crypt** | Ancestral wisdom storage (bloodlines) | Meeseeks AGI |
| **Delegation** | Hierarchical spawning with desperation scale | Meeseeks AGI |

### Quick Start: BDI Model

```gdscript
var bdi = AWR.get_bdi()

# Add beliefs about the world
bdi.believe("player_position", Vector2(100, 200), 0.9)
bdi.believe("goal_nearby", true, 1.0)

# Set desires (goals with priorities)
bdi.desire("reach_goal", 1.0)  # Highest priority
bdi.desire("avoid_hazards", 0.8)

# Commit to intentions
bdi.intend({"type": "move", "target": Vector2(900, 300)})

# Get current state as AI prompt
print(bdi.to_prompt_block())
```

### Quick Start: Global Workspace

```gdscript
var gw = AWR.get_global_workspace()

# Add competing content
gw.add_content("threat_detected", 0.9, "perception")
gw.add_content("goal_nearby", 0.7, "navigation")

# Run attention competition
gw.compete()

# Get conscious content (winner)
var conscious = gw.get_conscious_content()

# Broadcast to listeners
gw.broadcast()
```

### Quick Start: HTN Planner

```gdscript
# Create planner with navigation domain
var planner = AWR.get_htn_planner("navigation")

# Plan a compound task
var plan = AWR.htn_plan("navigate_to_goal")

# Convert to actions
var actions = planner.plan_to_actions(plan, "agent_1")

# Print plan
print(planner.plan_to_string(plan))
```

### Quick Start: Memory-Prediction

```gdscript
var mp = AWR.get_memory_prediction()

# Make predictions
mp.predict_value("next_position", Vector2(110, 110), 0.8)

# Observe actual
mp.observe("next_position", Vector2(115, 108))

# Learn from error
var lessons = mp.learn()
print("Accuracy: %.1f%%" % (mp.get_accuracy() * 100))
```

### Quick Start: Delegation System

```gdscript
var delegation = AWR.get_delegation()

# Check if should delegate
if delegation.should_delegate("complex_task", attempts=3):
    # Spawn subtask
    var result = delegation.spawn_subtask("complex_task")

    # ... execute subtask ...

    # Complete subtask
    delegation.complete_subtask(result.subtask_id, success)

# Escalate desperation if failing
delegation.escalate()
print("Desperation: %d, Strategy: %s" % [
    delegation.desperation_level,
    delegation.get_approach_strategy()
])
```

### Quick Start: The Crypt (Ancestral Wisdom)

```gdscript
# Entomb completed sessions
AWR.entomb_session("session_1", "navigate_to_goal", {
    "success": true,
    "attempts": 1,
    "tools": ["path_finder"]
})

# Inherit wisdom from bloodlines
var wisdom = AWR.inherit_wisdom("navigation")

# Get guidance for a task
var guidance = AWR.get_ancestral_guidance("navigate_to_goal")

# Persist the crypt
AWR.save_crypt("user://wisdom.crypt")
```

### Complete Cognitive Cycle

```gdscript
# Run full cognitive cycle (all AGI patterns integrated)
func _process(delta):
    var result = AWR.cognitive_cycle(
        viewport,
        possible_actions,
        eval_func,
        "navigate_to_goal"
    )

    # Result contains:
    # - bdi_state: Current beliefs/desires/intentions
    # - conscious_content: What won attention competition
    # - guidance: Ancestral wisdom
    # - htn_plan: Decomposed task plan
    # - simulation: Branch evaluation results
    # - committed: Whether action was committed
```

### Cognitive API Reference

| Method | Description |
|--------|-------------|
| `get_bdi()` | Get/create BDI model |
| `get_global_workspace()` | Get/create global workspace |
| `compete_for_attention()` | Run attention competition |
| `get_htn_planner(domain)` | Get/create HTN planner |
| `htn_plan(task)` | Plan task decomposition |
| `get_memory_prediction()` | Get/create prediction system |
| `predict_and_learn(...)` | Predict, observe, learn in one call |
| `get_delegation()` | Get/create delegation system |
| `should_delegate(task)` | Check if should delegate |
| `spawn_subtask(task)` | Spawn a subtask |
| `get_performance_monitor()` | Get/create performance tracker |
| `get_crypt()` | Get/create ancestral wisdom |
| `entomb_session(...)` | Store session wisdom |
| `inherit_wisdom(bloodline)` | Get ancestral lessons |
| `get_ancestral_guidance(task)` | Get task-specific guidance |
| `cognitive_cycle(...)` | Run complete AGI cycle |
| `get_cognitive_state()` | Get full state as AI prompt |

---

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

# Run new cognitive tests
godot --headless --path godot-test-project -s addons/awr/tests/test_cognitive.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_self_improvement.gd
```

## Performance

| Metric | Value |
|--------|-------|
| Branches/second | ~519 (CPU-only) |
| Latency per branch | ~1.93ms |
| Test coverage | 91+ tests passing |
| Determinism | 100% verified |
| AGI Patterns | 7 patterns implemented |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWR v0.3 Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ Perception   │───▶│  WorldState  │◀───│  WorldGen    │      │
│  │    Layer     │    │  (SceneGraph)│    │  (3D Gen)    │      │
│  └──────────────┘    └──────┬───────┘    └──────────────┘      │
│                             │                                   │
│         ┌───────────────────┼───────────────────┐              │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  BDI Model   │    │   SimLoop    │    │    HTN       │      │
│  │(Beliefs/     │    │ (Branching)  │    │  Planner     │      │
│  │ Desires/     │    │              │    │              │      │
│  │ Intentions)  │    └──────┬───────┘    └──────────────┘      │
│  └──────────────┘           │                                   │
│         │                   │                                   │
│         ▼                   ▼                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Global     │    │  CausalBus   │    │   Memory-    │      │
│  │  Workspace   │◀───│   (Events)   │───▶│ Prediction   │      │
│  │ (Attention)  │    └──────┬───────┘    └──────────────┘      │
│  └──────────────┘           │                                   │
│         │                   │                                   │
│         │         ┌────────┴────────┐                          │
│         │         │                 │                          │
│         ▼         ▼                 ▼                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ Self-Improve │    │  RealBridge  │    │  The Crypt   │      │
│  │   System     │    │ (DigitalTwin)│    │ (Ancestral   │      │
│  │              │    │              │    │  Wisdom)     │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────┐                                              │
│  │  Delegation  │ ◀── Hierarchical spawning with desperation   │
│  │   System     │                                              │
│  └──────────────┘                                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
addons/awr/
├── awr.gd                    # Main autoload
├── plugin.cfg
├── README.md
│
├── core/                     # Core primitives
│   ├── world_state.gd
│   ├── sim_loop.gd
│   ├── evaluator.gd
│   ├── causal_bus.gd
│   └── event_log.gd
│
├── cognitive/                # AGI patterns (v0.3)
│   ├── bdi_model.gd
│   ├── global_workspace.gd
│   ├── htn_planner.gd
│   ├── htn_domain.gd
│   ├── memory_prediction.gd
│   └── delegation.gd
│
├── self_improvement/         # Self-improvement (v0.3)
│   ├── performance_monitor.gd
│   ├── pattern_analyzer.gd
│   ├── strategy_generator.gd
│   └── validator.gd
│
├── crypt/                    # Ancestral wisdom (v0.3)
│   ├── crypt.gd
│   └── bloodline.gd
│
├── spatial/                  # Spatial memory (v0.2)
│   ├── spatial_memory.gd
│   ├── memory_node.gd
│   ├── spatial_path.gd
│   ├── spatial_index.gd
│   └── palace_builder.gd
│
├── perception/               # Perception
│   ├── perception_bridge.gd
│   ├── vlm_parser.gd
│   └── viewport_capture.gd
│
├── physics/                  # Physics
│   ├── collision_2d.gd
│   └── broadphase.gd
│
├── worldgen/                 # World generation
│   └── scene_generator.gd
│
├── realbridge/               # Digital twin
│   └── mqtt_client.gd
│
└── tests/                    # Test suite
    ├── run_all_tests.gd
    ├── test_cognitive.gd
    ├── test_self_improvement.gd
    └── ...
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
- **AGI agents** - Full cognitive architecture with BDI, attention, and learning
- **Self-improving systems** - Track performance and generate strategies
- **Ancestral wisdom** - Store and inherit lessons across sessions
- **Hierarchical delegation** - Spawn subtasks with desperation scaling

## License

MIT

## Credits

AWR is inspired by research in:
- Cognitive maps (O'Keefe, Moser & Moser - Nobel Prize 2014)
- World models (Ha & Schmidhuber 2018, LeCun's JEPA)
- Embodied cognition (Varela, Thompson, Rosch 1991)

# Spatial Arrow Nodes

3D nodes for spatial memory visualization in Godot 4.6.

## Concept

Each node has a **transform that IS its embedding** in semantic space:
- **Position (x,y,z)** = Location in concept space
- **Rotation** = Direction arrow points (for relationships)
- **Scale** = Importance/salience
- **Markdown (.md)** = Rich textual metadata for AI agents

## Node Types

### THING Nodes (Concepts)
Rendered as spheres. Represent concepts, entities, or places.

```gdscript
var concept = SpatialArrowNode.new()
concept.node_type = SpatialArrowNode.NodeType.THING
concept.concept = "machine_learning"
concept.concept_position = Vector3(50, 20, 0)
```

### ARROW Nodes (Relationships)
Rendered as 3D arrows pointing to targets. Represent relationships between concepts.

```gdscript
var arrow = SpatialArrowNode.new()
arrow.node_type = SpatialArrowNode.NodeType.ARROW
arrow.relationship = "has_subfield"
arrow.source_concept = "artificial_intelligence"
arrow.target_concept = "machine_learning"
```

## Markdown Metadata

Each node can have associated markdown files with YAML frontmatter:

```markdown
---
type: thing
name: machine_learning
position: 50, 20, 0
tags: [ai, learning, core]
---

# Machine Learning

A subset of artificial intelligence that enables systems to learn from data.

## Definition
Machine learning is the study of computer algorithms...

## Components
- Supervised Learning
- Unsupervised Learning
- Reinforcement Learning
```

## Installation

1. Copy `addons/spatial_arrows/` to your Godot project's `addons/` folder
2. Enable the plugin in Project Settings > Plugins
3. Or use directly by preloading the scripts

## Usage

### Basic Setup

```gdscript
const SpatialArrowNode = preload("res://addons/spatial_arrows/spatial_arrow_node.gd")
const SpatialMemory = preload("res://addons/spatial_arrows/spatial_memory.gd")

# Create a spatial memory
var memory = SpatialMemory.new(10.0)

# Store concepts
memory.store("ai", Vector3(0, 0, 0))
memory.store("ml", Vector3(50, 20, 0))

# Create arrow between them
var arrow = SpatialArrowNode.new()
arrow.node_type = SpatialArrowNode.NodeType.ARROW
arrow.relationship = "has_subfield"
arrow.source_concept = "ai"
arrow.target_concept = "ml"
arrow.spatial_memory = memory
add_child(arrow)
```

### 3D Visualization

```gdscript
const SpatialMemoryVisualizer = preload("res://addons/spatial_arrows/spatial_memory_visualizer.gd")

var viz = SpatialMemoryVisualizer.new()
viz.spatial_memory = memory
add_child(viz)
viz.refresh_visualization()
```

### Spatial Queries

```gdscript
# Find what's in a vision cone
var visible = memory.cone_query(origin, direction, PI/3, 100.0)

# Find what a concept is facing
var facing = memory.facing_what("agent", 50.0, PI/2)

# Find concepts to the left/right
var left = memory.relative_position("agent", "left")

# Find path between concepts
var path = memory.find_path("ai", "deep_learning")
```

## Files

| File | Purpose |
|------|---------|
| `spatial_arrow_node.gd` | THING/ARROW node with markdown metadata |
| `spatial_memory.gd` | Memory palace engine with spatial queries |
| `spatial_memory_visualizer.gd` | 3D visualization system |
| `memory_node.gd` | Core memory node with physics |
| `spatial_index.gd` | Spatial hashing for O(1) queries |
| `spatial_path.gd` | Path through concept space |

## License

MIT

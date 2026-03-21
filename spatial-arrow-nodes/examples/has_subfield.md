---
type: arrow
name: has_subfield
relationship: has_subfield
from: artificial_intelligence
to: machine_learning
position: 25, 10, 0
strength: 1.0
bidirectional: false
---

# has_subfield

Indicates that one field of study contains another as a subdiscipline.

## Definition

The "has_subfield" relationship connects a parent domain to a more specialized
area of study within that domain.

## Properties

- **Transitive**: If A has_subfield B and B has_subfield C, then A has_subfield C
- **Asymmetric**: If A has_subfield B, then B does not have_subfield A
- **Hierarchical**: Forms a tree structure of knowledge

## Examples

- Artificial Intelligence → Machine Learning
- Mathematics → Statistics
- Computer Science → Algorithms

## Inverse Relationship

The inverse is "is_subfield_of" (machine_learning is_subfield_of artificial_intelligence)

## Spatial Representation

In the memory palace:
- Source concept: `artificial_intelligence` at position (0, 0, 0)
- Target concept: `machine_learning` at position (50, 20, 0)
- Arrow direction: From AI toward ML
- Arrow length: Proportional to semantic distance

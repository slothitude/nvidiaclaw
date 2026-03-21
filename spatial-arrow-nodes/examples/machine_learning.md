---
type: thing
name: machine_learning
position: 50, 20, 0
tags: [ai, learning, core]
semantic_type: concept
salience: 0.8
confidence: 1.0
---

# Machine Learning

A subset of artificial intelligence that enables systems to learn from data.

## Definition

Machine learning is the study of computer algorithms that can improve automatically
through experience and by the use of data. It is seen as a part of artificial intelligence.

## Key Concepts

- **Supervised Learning**: Learning from labeled data
- **Unsupervised Learning**: Finding patterns in unlabeled data
- **Reinforcement Learning**: Learning through trial and error

## Relationships

- Part of: [artificial_intelligence](./artificial_intelligence.md)
- Uses: [neural_networks](./neural_networks.md)
- Includes: [reinforcement_learning](./reinforcement_learning.md)

## Examples

1. Image classification
2. Speech recognition
3. Recommendation systems

## Code Example

```python
from sklearn.linear_model import LogisticRegression

model = LogisticRegression()
model.fit(X_train, y_train)
predictions = model.predict(X_test)
```

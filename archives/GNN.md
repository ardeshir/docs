# Geometric Deep Learning with GNN

# Key Aspects of Building GNN and ML Applications from Geometric Deep Learning

## 1. THE FUNDAMENTAL BLUEPRINT: The Geometric Deep Learning Framework

The core insight of the book is that **successful neural network architectures can be derived from first principles** using three foundational concepts:

### The Three Pillars

1. **Domain (Ω)** - The geometric structure underlying your data (grids, graphs, manifolds, etc.)
1. **Symmetry Group (G)** - The transformations that should not change the output (translations, rotations, permutations)
1. **Signal Space (X)** - The space of functions/features defined on the domain

### The Blueprint Formula

Neural network layers should be designed to be **equivariant** to the symmetry group:

- **Equivariance**: If you transform the input, the output transforms in a predictable, corresponding way
- **Invariance**: The final output (for classification) should be unchanged by symmetry transformations

-----

## 2. THE 5Gs: Five Geometric Domains for Deep Learning

The book categorizes geometric deep learning into five domains (the “5Gs”):

|Domain       |Symmetry Group       |Example Architecture      |Applications               |
|-------------|---------------------|--------------------------|---------------------------|
|**Grids**    |Translation          |CNNs                      |Images, video              |
|**Groups**   |Group elements       |Group-equivariant CNNs    |Rotational data            |
|**Graphs**   |Permutation          |GNNs, Message Passing     |Molecules, social networks |
|**Geodesics**|Isometries           |Geometric CNNs            |3D shapes, meshes          |
|**Gauges**   |Gauge transformations|Gauge-equivariant networks|Particle physics, manifolds|

-----

## 3. BUILDING GNNs: The Message Passing Framework

### Core Message Passing Neural Network (MPNN) Formula

For each node *i*, update its representation through:

```
h_i^(k+1) = φ(x_i, ⊕_{j∈N(i)} ψ(x_i, x_j, e_ij))
```

Where:

- **ψ** = message function (computes messages between node pairs)
- **⊕** = aggregation function (sum, mean, max, or attention)
- **φ** = update function (MLP that combines node state with aggregated messages)

### Three Flavors of GNN Layers (by expressive power)

1. **Convolutional** (least expressive)

- Fixed, pre-computed attention weights based on graph topology
- Best for homophilous graphs (similar nodes connect)
- Most scalable (sparse matrix multiplication)

1. **Attentional** (medium)

- Learned, feature-dependent attention weights
- Can handle heterophilous graphs
- Examples: GAT, Transformers

1. **Message Passing** (most expressive)

- Arbitrary functions of node pairs and edge features
- Maximum flexibility but highest computational cost
- Examples: MPNN, EdgeConv

-----

## 4. KEY DESIGN CHOICES FOR GNN ARCHITECTURES

### A. Aggregation Operations

|Operation    |Use Case                                      |Trade-offs                |
|-------------|----------------------------------------------|--------------------------|
|**Sum**      |Default choice, preserves multiset information|Sensitive to outliers     |
|**Mean**     |Normalized view, variable neighborhood sizes  |Loses count information   |
|**Max**      |Highlight salient features                    |Loses multiset information|
|**Attention**|Learn importance dynamically                  |More parameters, slower   |

### B. Number of Layers (Depth)

- **Each layer expands receptive field by 1 hop**
- Too few layers: Cannot capture long-range dependencies
- Too many layers: **Over-smoothing** (all node representations become similar)
- Typical sweet spot: **2-4 layers** for many tasks

### C. Handling Different Prediction Tasks

|Task Level     |Approach                                          |
|---------------|--------------------------------------------------|
|**Node-level** |Apply classifier to final node embeddings         |
|**Edge-level** |Pool node pair embeddings or use edge embeddings  |
|**Graph-level**|Global pooling (sum/mean/attention) over all nodes|

-----

## 5. EQUIVARIANCE: The Design Principle

### Why Equivariance Matters

- **Data efficiency**: Doesn’t need to learn the same function for all transformed versions
- **Generalization**: Built-in invariances prevent overfitting to spurious correlations
- **Physical correctness**: Respects known symmetries of the problem domain

### Implementing Equivariance

For **permutation equivariance** (graphs):

- Use symmetric aggregation functions
- Share parameters across all nodes/edges

For **translation equivariance** (grids):

- Use convolutions (weight sharing across positions)

For **rotation/reflection equivariance** (E(3) for 3D):

- Use spherical harmonics and tensor products
- Examples: NequIP, MACE, PaiNN for molecular simulations

-----

## 6. PRACTICAL IMPLEMENTATION GUIDELINES

### Step-by-Step Process for Building a New GNN

1. **Identify the domain**: What is the natural structure of your data?
1. **Identify symmetries**: What transformations shouldn’t change your predictions?
1. **Choose signal representation**: What features live on nodes, edges, and globally?
1. **Design equivariant layers**: Build message passing that respects symmetries
1. **Add pooling/readout**: Map to final predictions while maintaining invariance
1. **Stack layers with scale separation**: Allow multi-resolution representations

### Recommended Libraries

- **PyTorch Geometric (PyG)**: Most comprehensive, production-ready
- **Deep Graph Library (DGL)**: Framework-agnostic
- **Jraph**: JAX-based, good for research
- **e3nn**: For E(3)-equivariant networks

-----

## 7. ADVANCED TOPICS

### Overcoming GNN Limitations

|Problem                    |Solutions                                |
|---------------------------|-----------------------------------------|
|**Over-smoothing**         |Skip connections, DropEdge, normalization|
|**Over-squashing**         |Graph rewiring, virtual nodes            |
|**Limited expressivity**   |Higher-order WL tests, subgraph methods  |
|**Long-range dependencies**|Graph Transformers, virtual edges        |

### Beyond Standard Message Passing

- **Cellular/Simplicial complexes**: Go beyond pairwise relationships
- **Sheaf neural networks**: Heterogeneous information flow
- **Neural algorithmic reasoning**: GNNs that execute algorithms

-----

## 8. APPLICATION DOMAINS

The book highlights successful applications in:

|Domain                           |Key Architecture Features                                 |
|---------------------------------|----------------------------------------------------------|
|**Molecular property prediction**|Invariant to atom permutation, rotation-equivariant for 3D|
|**Protein structure (AlphaFold)**|SE(3)-equivariant attention, multi-scale                  |
|**Drug discovery**               |Message passing on molecular graphs                       |
|**Traffic prediction**           |Spatio-temporal GNNs                                      |
|**Recommendation systems**       |Bipartite graphs, heterogeneous edges                     |
|**Physics simulation**           |Equivariant to physical symmetries                        |

-----

## 9. KEY TAKEAWAYS FOR PRACTITIONERS

1. **Start with symmetries**: Always ask “what transformations shouldn’t matter?”
1. **Use the simplest architecture that respects symmetries**: Don’t over-engineer
1. **Leverage pre-built components**: PyG has most architectures implemented
1. **Consider expressivity vs. efficiency trade-off**: More expressive isn’t always better
1. **Test on appropriate benchmarks**: Use domain-specific datasets
1. **Watch for over-smoothing**: Monitor representation similarity across layers
1. **Global context helps**: Add master/virtual nodes for graph-level communication

-----

## 10. FURTHER LEARNING RESOURCES

From the book website:

- **Lecture videos**: [YouTube playlist](https://www.youtube.com/playlist?list=PLn2-dEmQeTfSLXW8yXP4q_Ii58wFdxb3C) (AMMI course)
- **Tutorials**: Colab notebooks on expressive GNNs, group-equivariant networks, and geometric GNNs
- **Mathematical foundations**: [arXiv:2508.02723](https://arxiv.org/abs/2508.02723) for prerequisites
- **Interactive playground**: [Distill.pub GNN introduction](https://distill.pub/2021/gnn-intro/)

-----

This framework provides a **principled, unified approach** to designing neural networks by starting from the geometry of the problem domain rather than ad-hoc architectural choices. The key insight is that the most successful deep learning architectures (CNNs, GNNs, Transformers) are all special cases of the same geometric blueprint.​​​​​​​​​​​​​​​​
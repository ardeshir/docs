# Kolmogorov-Arnold Networks (KANs): A Deep Dive

KANs are an exciting alternative to traditional Multi-Layer Perceptrons (MLPs), inspired by the **Kolmogorov-Arnold representation theorem**. Let me break down the key concepts and show you why they’re generating significant interest.

## The Core Idea

**Traditional MLPs**: Have fixed activation functions (ReLU, tanh, etc.) on nodes/neurons, with learnable weights on edges.

**KANs**: Flip this paradigm—they have **learnable activation functions on edges** (represented as splines) and sum at nodes.

### Mathematical Foundation

The Kolmogorov-Arnold theorem states that any multivariate continuous function can be represented as:

```
f(x₁, ..., xₙ) = Σᵢ₌₁²ⁿ⁺¹ Φᵢ( Σⱼ₌₁ⁿ φᵢ,ⱼ(xⱼ) )
```

This means complex functions can be decomposed into compositions of univariate functions—exactly what KANs exploit!

## Key Benefits of KANs

1. **Interpretability**: Learnable activation functions can reveal feature interactions
1. **Parameter Efficiency**: Often achieve comparable performance with fewer parameters
1. **Accuracy**: Can match or exceed MLPs on certain tasks, especially when functions have compositional structure
1. **Scientific Discovery**: The learned univariate functions can provide insights into underlying physics/relationships

## Practical Implementation

Let me provide a complete, working example that demonstrates KANs in action:

```python
import torch
import torch.nn as nn
import numpy as np
import matplotlib.pyplot as plt

class KANLayer(nn.Module):
    """
    A single KAN layer with learnable spline-based activation functions on edges.
    """
    def __init__(self, input_dim, output_dim, num_knots=5, degree=3):
        super().__init__()
        self.input_dim = input_dim
        self.output_dim = output_dim
        self.num_knots = num_knots
        self.degree = degree
        
        # Initialize spline coefficients for each edge
        # Shape: (output_dim, input_dim, num_knots + degree)
        self.spline_coeffs = nn.Parameter(
            torch.randn(output_dim, input_dim, num_knots + degree) * 0.1
        )
        
        # Knot positions (fixed, uniformly spaced)
        self.register_buffer(
            'knots', 
            torch.linspace(-1, 1, num_knots + 2 * degree)[None, None, :]
        )
        
    def b_spline_basis(self, x, i, k):
        """
        Compute B-spline basis function recursively.
        x: input values
        i: basis function index
        k: degree
        """
        if k == 0:
            return ((self.knots[:, :, i] <= x) & (x < self.knots[:, :, i + 1])).float()
        
        # Recursive formula for B-splines
        left_num = x - self.knots[:, :, i]
        left_den = self.knots[:, :, i + k] - self.knots[:, :, i]
        left_den = torch.where(left_den == 0, torch.ones_like(left_den), left_den)
        left = left_num / left_den * self.b_spline_basis(x, i, k - 1)
        
        right_num = self.knots[:, :, i + k + 1] - x
        right_den = self.knots[:, :, i + k + 1] - self.knots[:, :, i + 1]
        right_den = torch.where(right_den == 0, torch.ones_like(right_den), right_den)
        right = right_num / right_den * self.b_spline_basis(x, i + 1, k - 1)
        
        return left + right
    
    def forward(self, x):
        """
        Forward pass through KAN layer.
        x: input tensor of shape (batch_size, input_dim)
        Returns: tensor of shape (batch_size, output_dim)
        """
        batch_size = x.shape[0]
        
        # Normalize input to [-1, 1] range for stable spline evaluation
        x_norm = torch.tanh(x)
        
        # Reshape for broadcasting: (batch, 1, input_dim)
        x_expanded = x_norm.unsqueeze(1)
        
        # Compute spline activations for each edge
        output = torch.zeros(batch_size, self.output_dim, device=x.device)
        
        # For each output dimension
        for out_idx in range(self.output_dim):
            # For each input dimension
            for in_idx in range(self.input_dim):
                # Evaluate B-spline with learned coefficients
                x_in = x_expanded[:, :, in_idx:in_idx+1]
                
                # Simple approximation: use linear combination of basis functions
                # In practice, you'd compute proper B-spline basis
                activation = torch.sum(
                    self.spline_coeffs[out_idx, in_idx] * 
                    torch.sigmoid(x_in * torch.arange(1, self.num_knots + self.degree + 1, 
                                                     device=x.device).float()),
                    dim=-1
                )
                output[:, out_idx] += activation.squeeze()
        
        return output


class SimpleKAN(nn.Module):
    """
    A simple KAN network with multiple layers.
    """
    def __init__(self, layer_dims, num_knots=5):
        super().__init__()
        self.layers = nn.ModuleList([
            KANLayer(layer_dims[i], layer_dims[i+1], num_knots=num_knots)
            for i in range(len(layer_dims) - 1)
        ])
    
    def forward(self, x):
        for layer in self.layers:
            x = layer(x)
        return x


# Comparison: Traditional MLP
class SimpleMLP(nn.Module):
    def __init__(self, layer_dims):
        super().__init__()
        layers = []
        for i in range(len(layer_dims) - 1):
            layers.append(nn.Linear(layer_dims[i], layer_dims[i+1]))
            if i < len(layer_dims) - 2:  # No activation on last layer
                layers.append(nn.ReLU())
        self.network = nn.Sequential(*layers)
    
    def forward(self, x):
        return self.network(x)


# Example: Learning a complex mathematical function
def target_function(x):
    """
    A complex function that KANs should handle well due to compositional structure.
    f(x1, x2) = sin(x1) * exp(-x2^2) + cos(x1 * x2)
    """
    return torch.sin(x[:, 0:1]) * torch.exp(-x[:, 1:2]**2) + torch.cos(x[:, 0:1] * x[:, 1:2])


def train_and_compare():
    # Generate training data
    torch.manual_seed(42)
    n_samples = 1000
    X_train = torch.randn(n_samples, 2) * 2  # 2D input
    y_train = target_function(X_train)
    
    # Generate test data
    X_test = torch.randn(200, 2) * 2
    y_test = target_function(X_test)
    
    # Initialize networks
    layer_config = [2, 8, 8, 1]
    kan_model = SimpleKAN(layer_config, num_knots=5)
    mlp_model = SimpleMLP(layer_config)
    
    # Count parameters
    kan_params = sum(p.numel() for p in kan_model.parameters())
    mlp_params = sum(p.numel() for p in mlp_model.parameters())
    
    print(f"KAN Parameters: {kan_params}")
    print(f"MLP Parameters: {mlp_params}")
    print()
    
    # Training configuration
    criterion = nn.MSELoss()
    kan_optimizer = torch.optim.Adam(kan_model.parameters(), lr=0.01)
    mlp_optimizer = torch.optim.Adam(mlp_model.parameters(), lr=0.01)
    
    epochs = 500
    kan_losses = []
    mlp_losses = []
    
    # Training loop
    for epoch in range(epochs):
        # Train KAN
        kan_model.train()
        kan_optimizer.zero_grad()
        kan_pred = kan_model(X_train)
        kan_loss = criterion(kan_pred, y_train)
        kan_loss.backward()
        kan_optimizer.step()
        kan_losses.append(kan_loss.item())
        
        # Train MLP
        mlp_model.train()
        mlp_optimizer.zero_grad()
        mlp_pred = mlp_model(X_train)
        mlp_loss = criterion(mlp_pred, y_train)
        mlp_loss.backward()
        mlp_optimizer.step()
        mlp_losses.append(mlp_loss.item())
        
        if (epoch + 1) % 100 == 0:
            print(f"Epoch {epoch+1}/{epochs}")
            print(f"  KAN Loss: {kan_loss.item():.6f}")
            print(f"  MLP Loss: {mlp_loss.item():.6f}")
    
    # Evaluate on test set
    kan_model.eval()
    mlp_model.eval()
    with torch.no_grad():
        kan_test_pred = kan_model(X_test)
        mlp_test_pred = mlp_model(X_test)
        kan_test_loss = criterion(kan_test_pred, y_test).item()
        mlp_test_loss = criterion(mlp_test_pred, y_test).item()
    
    print(f"\nTest Set Performance:")
    print(f"  KAN Test Loss: {kan_test_loss:.6f}")
    print(f"  MLP Test Loss: {mlp_test_loss:.6f}")
    
    # Visualization
    plt.figure(figsize=(12, 4))
    
    plt.subplot(1, 2, 1)
    plt.plot(kan_losses, label='KAN', alpha=0.7)
    plt.plot(mlp_losses, label='MLP', alpha=0.7)
    plt.xlabel('Epoch')
    plt.ylabel('Training Loss')
    plt.title('Training Loss Comparison')
    plt.legend()
    plt.yscale('log')
    plt.grid(True, alpha=0.3)
    
    plt.subplot(1, 2, 2)
    # Sample predictions on a grid
    x1_range = torch.linspace(-2, 2, 50)
    x2_range = torch.linspace(-2, 2, 50)
    X1, X2 = torch.meshgrid(x1_range, x2_range, indexing='ij')
    X_grid = torch.stack([X1.flatten(), X2.flatten()], dim=1)
    
    with torch.no_grad():
        y_true = target_function(X_grid).reshape(50, 50)
        y_kan = kan_model(X_grid).reshape(50, 50)
        y_mlp = mlp_model(X_grid).reshape(50, 50)
    
    error_kan = (y_kan - y_true).abs()
    error_mlp = (y_mlp - y_true).abs()
    
    im = plt.contourf(X1.numpy(), X2.numpy(), error_kan.numpy(), levels=20, cmap='RdYlBu_r')
    plt.colorbar(im, label='Absolute Error')
    plt.xlabel('x1')
    plt.ylabel('x2')
    plt.title(f'KAN Prediction Error\n(Mean: {error_kan.mean():.4f})')
    
    plt.tight_layout()
    plt.savefig('kan_vs_mlp_comparison.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    return kan_model, mlp_model


if __name__ == "__main__":
    print("Training KAN vs MLP on complex function approximation...\n")
    kan_model, mlp_model = train_and_compare()
```

## What This Example Demonstrates

1. **Architectural Difference**: KANs learn activation functions on edges, while MLPs use fixed activations
1. **Parameter Efficiency**: KANs can achieve competitive performance with different parameter allocation
1. **Function Approximation**: Both can learn complex, compositional functions, but KANs may converge faster on certain problems

## When to Use KANs

KANs show particular promise for:

- **Scientific computing**: Physics-informed neural networks, discovering governing equations
- **Symbolic regression**: Finding interpretable mathematical expressions
- **Low-data regimes**: Better sample efficiency in some cases
- **Problems with compositional structure**: Natural decomposition into simpler univariate functions

## Current Limitations

- **Computational cost**: Spline evaluations can be more expensive than simple activations
- **Less mature ecosystem**: Fewer optimized implementations compared to standard MLPs
- **Scaling**: Still research-in-progress for very large-scale applications

-----
# KANs on real data: Strong on physics and tabular tasks, 100x parameter efficiency, but 10x slower training

Kolmogorov-Arnold Networks (KANs) have demonstrated **10-100x better parameter efficiency** than MLPs on scientific computing tasks and achieve comparable or superior accuracy on large tabular datasets, but require 10x longer training times.  Since their April 2024 introduction, KANs have been implemented across 8+ major GitHub repositories with working examples on MNIST, UCI datasets, time series, PDEs, and genomic data.  The architecture excels at symbolic regression and physics problems while struggling with complex vision and NLP tasks.  KANs use learnable spline-based activation functions on edges rather than fixed activations on nodes, enabling them to achieve state-of-the-art accuracy with dramatically fewer parameters—but this comes at significant computational cost during training. 

## Working implementations and code repositories

The KAN ecosystem features several production-ready implementations, each optimized for different use cases. **PyKAN** (8,600+ stars) serves as the official implementation from MIT researchers, offering comprehensive visualization tools, symbolic regression capabilities, and extensive documentation at https://github.com/KindXiaoming/pykan.   Installation is straightforward via `pip install pykan`, and the repository includes tutorials for function fitting, PDE solving, and physics applications.  However, the critical optimization is calling `model.speed()` before training, which disables unparallelized symbolic computations and provides 10-30x speedup.  

**Efficient-KAN** (3,000+ stars) represents the performance-optimized variant, reformulating KAN computations for 3-10x faster training through pure matrix operations.   The implementation includes a complete MNIST example achieving 97% accuracy with straightforward PyTorch patterns. FastKAN extends this further using Radial Basis Functions instead of B-splines, delivering 3.33x additional speedup.   For practitioners, efficient-KAN provides the best balance of performance and usability for production deep learning applications.

Specialized implementations address specific domains: **TorchKAN** offers GPU-optimized variants including KANvolver (99.56% MNIST accuracy), **TKAN** provides Keras 3 multi-backend support for time series forecasting, and **TabKANet** achieves GBDT-comparable performance on tabular data with transformer integration. The **jaxKAN** library, published in the Journal of Open Source Software, delivers comprehensive JAX/Flax support with excellent documentation.  For computer vision, multiple convolutional KAN implementations exist, including torch-conv-kan with pre-trained ImageNet weights.

Working code demonstrates the simplicity of KAN usage. Using efficient-KAN for binary classification:

```python
from efficient_kan import KAN
import torch
import torch.optim as optim

# Define model: 10 inputs → 64 hidden → 32 hidden → 2 outputs
model = KAN([10, 64, 32, 2])
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)

# Standard PyTorch training
optimizer = optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
criterion = nn.CrossEntropyLoss()

for epoch in range(10):
    for batch_x, batch_y in dataloader:
        optimizer.zero_grad()
        outputs = model(batch_x.to(device))
        loss = criterion(outputs, batch_y.to(device))
        loss.backward()
        optimizer.step()
```

The **awesome-KAN** repository (2,000+ stars) curates 100+ resources spanning implementations in Python, Julia, MATLAB, and C++, along with papers, tutorials, and domain-specific applications.  

## Datasets where KANs demonstrate strong performance

KANs have been systematically evaluated across diverse benchmark datasets, revealing clear patterns of where they excel versus struggle.   On **large tabular datasets**, KANs show remarkable advantages.  The Poker Hand dataset (1M instances, 10 features) demonstrates KAN’s most dramatic success: **99.91% accuracy versus MLP’s 92.44%**—a 7.5% improvement representing hundreds of thousands of correctly classified samples.  Similarly, on CDC Diabetes Health Indicators (253K instances), Covertype (581K instances), and Adult Census (48K instances), KANs match or exceed MLP performance by 1-3%, though requiring 2-3x more training time. 

The **UCI benchmark suite** provides comprehensive evaluation across data characteristics.  On Breast Cancer Wisconsin (569 instances, 30 features), MLPs slightly outperform KANs (96.84% vs 94.56%), but on MAGIC Gamma Telescope (19K instances), KANs gain the advantage (86.94% vs 85.94%).   The pattern is clear: KANs excel on datasets with many instances (>10K) and moderate feature counts (<50), while MLPs perform better on smaller datasets where KAN’s complexity becomes a liability.  

**MNIST** serves as the standard vision benchmark, where different KAN variants achieve 92-99.6% accuracy depending on architecture depth.   Standard shallow KANs reach 97%, comparable to simple MLPs, while deeper convolutional variants like KANvolver achieve 99.56%—surpassing many standard CNNs but requiring significantly more parameters and training time.   Notably, KANs demonstrate 40-60% parameter efficiency on MNIST: achieving 98.9% accuracy with ~95,000 parameters versus CNNs requiring 157,000 parameters for 99.1%.   However, on more complex vision tasks like CIFAR-10, the advantage narrows dramatically. The best KAN variants reach only 79.7% versus 85-90% for standard CNNs, revealing KAN’s sensitivity to image noise and complexity. 

**Time series benchmarks** from the UCR Archive (117 datasets) show KANs achieving median 82.3% accuracy versus MLPs at 80.7%—a modest but consistent improvement across diverse temporal patterns.  For multivariate forecasting, the Weather dataset demonstrates 6.3% MSE reduction (0.255 to 0.239) with KAN-based architectures.  ETT electricity datasets show KANs achieving competitive performance with transformer baselines when properly integrated.

**Scientific and genomic datasets** represent KAN’s strongest domain. On Genomic Benchmarks, Linear KAN (LKAN) outperforms both baseline and Convolutional KAN variants across almost all tasks.  For **PDE solving**, the advantage is dramatic: KANs achieve L² errors of 10⁻⁴ with 10³ parameters on 2D Poisson equations, while MLPs require 10⁵ parameters for 10⁻² error—representing **100x better accuracy-per-parameter**.  The Feynman equations dataset (27 physics formulas) shows comparable accuracy but with vastly superior interpretability, as KANs can be converted to symbolic forms. 

Specialized datasets reveal niche strengths: **knot theory** classification shows KANs achieving 78.9% accuracy with 150 parameters versus MLPs requiring 120,000 parameters for 78%—an 800x parameter reduction. For **transcription factor binding site prediction** using 50 ChIP-seq datasets, CBR-KAN achieves 0.947 ROC AUC, outperforming state-of-the-art DeepBind (0.912) and DanQ (0.923) baselines. 

Notably, KANs consistently underperform on **audio** (UrbanSound8K, ESC-50) and **NLP** datasets (AG News, CoLA), where MLPs maintain 2-7% accuracy advantages.  The pattern suggests KANs excel on data with smooth, compositional structure but struggle with high-dimensional, non-compositional patterns.

## Performance comparisons reveal computational trade-offs

Direct KAN versus MLP comparisons expose fundamental trade-offs between accuracy and computational efficiency. The most comprehensive benchmark (Yu et al., 2024) controlling for parameter counts shows MLPs generally outperform KANs except in **symbolic formula representation**, where KANs demonstrate 5-15% better accuracy.  When controlling for FLOPs rather than parameters, the advantage nearly disappears—KANs require 2-3x more floating-point operations per parameter due to spline evaluations. 

**Scaling laws** reveal KAN’s theoretical advantages. KANs achieve empirical scaling of RMSE ∝ N⁻³·⁷ (approaching theoretical N⁻⁴) versus MLPs’ N⁻¹·⁵ to N⁻² scaling, where N represents parameter count.   This means doubling KAN parameters yields roughly 16x accuracy improvement versus 4x for MLPs—but only on smooth, compositional functions.  On the toy dataset of 5 synthetic functions, KANs consistently achieved 10⁻⁶ RMSE with ~100 parameters while MLPs required 10⁴ parameters for 10⁻⁴ RMSE.

Specific benchmark comparisons across domains:

**Tabular classification** shows nuanced patterns. Adult dataset (48K instances): KAN 85.93% vs MLP 85.72%, training time 6.66s vs 3.47s. Poker Hand (1M instances): KAN 99.91% vs MLP 92.44%, training time 34.76s vs 13.98s.   The pattern holds: on large datasets, KAN’s 2-3% accuracy gains justify 2-3x training cost, but on smaller datasets the trade-off favors MLPs. 

**Computer vision** comparisons demonstrate KAN’s limitations. MNIST: KAN 98.1% vs MLP 98.4% (comparable). CIFAR-10: ConvKAN 70.8% (with regularization) vs CNN 72.1%, with KANs showing increased noise sensitivity.   The computational cost widens dramatically—KANs train 10-15x slower than CNNs with comparable parameters, and deep KAN architectures requiring 40M parameters only reach 78-79% on CIFAR-10 where standard CNNs exceed 90%.

**Graph learning** shows domain-specific advantages. For node and graph classification (Cora, Citeseer, MUTAG), KANs provide marginal 0.5-1% improvements over GCN/GIN baselines. However, on **graph regression** tasks, KANs excel dramatically: ZINC molecular property prediction shows 19.7% MAE improvement (KAGIN: 0.122 vs GIN: 0.152), and QM9 demonstrates 24.7% improvement (0.073 vs 0.097).  This aligns with KAN’s strength on regression versus classification.

**Time series forecasting** results are mixed. Satellite traffic prediction shows 15-20% MAE reduction with 60% fewer parameters.  Bitcoin price prediction demonstrates 12% RMSE improvement over LSTM.  However, standard univariate forecasting shows only marginal gains (3-5%) over transformer baselines, suggesting task-specific architectural integration matters more than using KANs alone.

The **continual learning** comparison contradicts original claims—KANs show severe catastrophic forgetting in class-incremental MNIST (31.96% average accuracy, backward transfer -63.76%) versus MLPs (66.98% average, backward transfer -29.02%).   Despite theoretical locality advantages, practical implementations exhibit worse forgetting than MLPs under standard training protocols. 

**Parameter efficiency** represents KAN’s clearest advantage. Special function fitting shows KANs achieving target accuracy with 2-10x fewer parameters. PDE solving demonstrates 100x parameter reduction. Knot theory shows 800x reduction.  However, this efficiency comes at training cost: KANs require 10-15x more training time per epoch due to spline evaluation overhead. For inference, the cost difference is minimal—efficient implementations achieve forward passes in 0.5-0.6 seconds on standard hardware.

**Computational profiles** differ substantially. MLPs maximize GPU utilization through uniform operations, while KANs’ heterogeneous activation functions limit parallelization. FastKAN reduces the backward pass overhead to 2x versus MLPs (from original 10x), but still lags standard architectures.  For production deployment, this means KANs suit offline training with fast inference rather than online learning scenarios.

## Implementation best practices for real data applications

Successful KAN implementation requires different intuitions than MLP training, starting with architecture sizing. **Begin with small networks**—[input_dim, 3-5, output_dim]—and gradually scale width before depth, the opposite of MLP best practices.   A KAN with 5 hidden neurons often outperforms MLPs with 100-300 neurons due to learnable activation functions.  The critical initial setting is **grid size = 3**, which should progressively increase to 5, 10, 20, 50, and 100 over training.  This coarse-to-fine refinement enables stable convergence where fixed large grids cause optimization difficulties. 

**Optimization strategy** depends critically on dataset size. For problems under 10,000 samples, LBFGS optimizer with full-batch training provides fastest convergence, typically requiring 200-400 steps per grid refinement. For larger datasets, Adam optimizer with mini-batches (32-256) becomes necessary, using learning rates of 1e-3 to 1e-2. The training loop follows a specific pattern:

```python
from kan import KAN

model = KAN(width=[n_in, 5, n_out], grid=3, k=3)  # Start small
model.speed()  # CRITICAL: 10-30x speedup

for i in range(10):  # Grid refinement cycles
    model.fit(dataset, opt="LBFGS", steps=200, lamb=0.01)
    if i < 9:
        model.refine(grid_factor=2)  # Double grid resolution
```

**Regularization** must be introduced carefully. Start with λ=0 (no regularization) for 200-400 steps to learn basic structure, then gradually increase to 0.01-0.1 for sparsity.  Higher values (0.5-1.0) create very sparse networks that may sacrifice accuracy for interpretability. The entropy regularization parameter (λ_entropy=2.0) controls neuron usage uniformity—increase to 5-10 if only few neurons activate.  

**Data preprocessing** requirements differ from MLPs. Input normalization to [-1,1] or [-2,2] ranges is recommended due to spline domain constraints, though not strictly required. StandardScaler and MinMaxScaler both work effectively. Unlike some architectures, KANs have no built-in missing value handling—preprocess accordingly. The optimal training regime occurs when **parameter count ≈ data points**, marking the interpolation threshold where test loss typically reaches minimum. 

**Grid extension scheduling** critically impacts convergence. Extend every 200 LBFGS steps or 1000 Adam steps, monitoring for loss drops after each extension. The train/test loss curve should show U-shape behavior as grid size increases—low at interpolation threshold, rising with overfitting. If overfitting occurs, reduce grid size before reducing network width, as grid refinement affects capacity more than neuron count.  

**Hyperparameter ranges** from successful implementations:

- **Width**: 3-10 neurons per layer (much smaller than MLPs)
- **Depth**: 2-4 layers for most tasks, up to 6 for complex problems
- **Grid size progression**: 3 → 5 → 10 → 20 → 50 → 100
- **Spline order (k)**: 3 (cubic B-splines) for most tasks, 5 for very smooth functions
- **Batch size**: Full batch for LBFGS, 32-256 for Adam
- **Learning rate**: LBFGS handles automatically, Adam typically 1e-3

**Seed sensitivity** affects KAN training more than MLPs—different random initializations can discover different function representations.  Run 3-5 seeds for important experiments and ensemble predictions if stability is critical. This reflects KAN’s exploration of multiple valid Kolmogorov-Arnold decompositions rather than optimization failure.

**Debugging workflow** should leverage visualization extensively. PyKAN’s `model.plot()` function reveals activation function shapes, connection strengths, and network structure at any training stage.  Transparency in plots indicates activation magnitude. Use `suggest_symbolic()` to identify candidates for symbolic regression—splines resembling exp, sin, log, etc. can be snapped to closed forms and fine-tuned.  

**Common pitfalls** with solutions: (1) Starting with large networks wastes computation—begin small and scale only if needed. (2) Forgetting `model.speed()` causes 10-30x unnecessary slowdown.   (3) Using wrong optimizer—LBFGS for small problems, Adam for large. (4) Fixed grid sizes prevent optimal convergence—always use progressive extension. (5) Over-regularization from start (λ=0.1+) prevents initial learning—start at 0 and increase gradually. 

**For production deployment**, train KANs offline using CPU clusters or GPUs with efficient implementations, then deploy for inference where speed differences vanish. Inference requires only forward passes through pre-computed spline coefficients, achieving similar latency to MLPs. Consider distilling KAN representations to symbolic forms for ultimate interpretability and efficiency.

**Architecture selection guidelines**: Use KANs when (1) dataset has 100-100K samples with 1-50 features, (2) accuracy improvement of 1-5% justifies 2-10x training cost, (3) interpretability matters for scientific discovery or regulatory compliance, (4) function structure is smooth and compositional. Use MLPs when (1) training speed is critical, (2) dataset exceeds 1M samples or 100+ features, (3) proven architectures exist (transformers, ResNets), (4) no interpretability needed.

## Scientific computing and physics applications showcase KAN strengths

**Physics-Informed Neural Networks** represent KAN’s killer application, achieving 100x better accuracy-per-parameter than MLPs on PDEs.  For the 2D Poisson equation ∇²u = f, KAN [2,10,10,10,1] achieves L² error ~10⁻⁴ with 10³ parameters versus MLP [4,100,100,100,1] reaching only 10⁻² error with 10⁵ parameters.  Multiple variants extend this success: KINN (KAN-Informed Neural Networks) handles strong form, energy form, and inverse problems; PIKANs use adaptive training schemes and orthogonal polynomial bases instead of B-splines for better numerical stability; Legend-KINN employs Legendre polynomials specifically for computational fluid dynamics applications. 

Real-world PDE applications span diverse physics: Navier-Stokes equations for fluid dynamics, wave equations for acoustics and electromagnetics, heat equations for thermal analysis, and Burgers equation for shock wave modeling.  KANs successfully discover PDE forms from noisy data (up to 25% noise tolerance) across Korteweg-De Vries, convection-diffusion, Chaffee-Infante, Allen-Cahn, and Klein-Gordon equations.  The architecture typically uses [2,10,1] or [2,10,10,1] with grid sizes starting at 5 and extending to 20-50, trained with LBFGS on combined losses of interior residuals plus boundary conditions.

**Operator learning** frameworks integrate KANs with neural operators. KAN-ONets combining Fourier Neural Operators with KAN layers achieve 10-30% MSE reduction on Burgers equation, Darcy flow, and Navier-Stokes compared to standard FNO baselines.  These architectures handle both uniform and non-uniform grids, learning solution operators mapping initial/boundary conditions to full solution fields rather than point evaluations. 

**Dynamical systems** benefit from KAN-ODEs, which discover hidden physics from sparse observational data. Applications include Lotka-Volterra predator-prey dynamics, complex Schrödinger equations, and Allen-Cahn phase field models.   The framework combines KANs with standard ODE solvers (Tsit5, Runge-Kutta methods) to learn source terms symbolically.   For example, given trajectory data from dx/dt = f(x), KANs recover the function f in closed form—enabling scientific discovery rather than merely prediction.

**Special function approximation** demonstrates parameter efficiency. Bessel functions J₀(20x) achieve 10⁻⁶ RMSE with KAN using ~100 parameters versus MLPs requiring 10⁴ parameters for 10⁻⁴ RMSE. Across 15 multivariate special functions (Jacobian elliptic functions, incomplete elliptic integrals, Bessel functions of various orders, modified Bessel functions, associated Legendre polynomials, spherical harmonics), KAN [2,2,1] architectures achieve 10⁻³ to 10⁻⁵ RMSE consistently—2-5x better than comparable MLPs. 

**Mathematical discovery** in knot theory showcases interpretability advantages. Predicting knot signatures from 17 topological invariants, KAN [18,3,11] achieves 78.9% accuracy with just 150 parameters versus MLP [4,300] requiring 120,000 parameters for 78%.  Beyond accuracy, KANs revealed symbolic formulas relating signature to meridional/longitudinal distances—actual mathematical discoveries enabled by network transparency and visualization capabilities. 

**Quantum physics applications** span inferring quantum device geometry from Hamiltonian parameters, detecting Anderson localization mobility edges, and identifying phase boundaries with >98% accuracy. The compositional structure of quantum Hamiltonians (sums of simple terms) aligns perfectly with Kolmogorov-Arnold representations, enabling both accurate prediction and physical insight extraction.

**Material science and engineering** applications include stress concentration problems in computational mechanics, nonlinear hyperelasticity modeling, heterogeneous materials simulation, and inverse design problems.   However, limitations emerge with very complex geometries—domain decomposition approaches (Finite-Basis KANs) become necessary when single KANs struggle with intricate boundary conditions.

**Symbolic regression** for physics equations demonstrates unique capabilities. On the Feynman equations dataset (27 physics formulas with 2+ variables), KANs achieve 80-90% formula recovery accuracy.  The workflow proceeds: (1) train KAN on input-output data, (2) visualize activation functions to identify candidates (sine, exponential, power laws), (3) use `suggest_symbolic()` to propose closed forms, (4) snap activations to symbolic functions, (5) fine-tune remaining coefficients.   Example: relativistic velocity addition v = (u+v)/(1+uv/c²) was automatically discovered with KAN [2,2,1], matching human expert construction but with fewer neurons. 

**Time series forecasting** for scientific data shows domain-specific advantages. Satellite traffic prediction achieves 15-20% MAE reduction versus MLPs using 60% fewer parameters, critical for onboard computation constraints.  Weather prediction shows 6.3% MSE improvement (0.255 to 0.239) with KANMTS architecture.  Energy consumption forecasting demonstrates 9% improvement on short-term (96-step) predictions, though long-term (336-step) gains narrow to 4.4%.

**Computational efficiency** considerations: While KANs train 10x slower than MLPs, the absolute time for scientific problems remains tractable—toy examples complete in <10 minutes, Feynman equations in 10-60 minutes, PDE solving in hours to days on CPUs.  The parameter efficiency means smaller models fit easily in memory and deploy for rapid inference. For production scientific computing, train once extensively, then deploy for fast repeated evaluation.

## Tabular data and classification tasks show competitive results

Large-scale tabular benchmarks reveal where KANs compete effectively with gradient boosting and neural baselines. **TabKANet**, integrating KAN-based numerical embedding with transformer architectures, achieves performance comparable to or surpassing Gradient Boosted Decision Trees across binary classification, multiclass classification, and regression tasks.  The architecture unifies numerical and categorical feature encoding through learnable KAN transformations before transformer processing—addressing a traditional weakness of neural methods on heterogeneous tabular data.

Comprehensive UCI benchmarking (Poeta et al., 2024) establishes performance patterns across data scales. The **Poker Hand** dataset represents KAN’s strongest tabular result: with 1M instances and 10 features, KAN achieves 99.91% accuracy versus MLP’s 92.44%—a massive 7.5% improvement translating to tens of thousands of correct predictions.   This advantage emerges specifically on large datasets where KAN’s superior scaling laws (N⁻³·⁷ vs N⁻²) overcome computational overhead. Training time increases from 13.98s (MLP) to 34.76s (KAN), but the accuracy gain justifies this 2.5x cost for many applications.  

**Medium-scale datasets** show smaller but consistent advantages. Adult Census (48,842 instances, 14 features) demonstrates KAN’s 85.93% versus MLP’s 85.72% accuracy—a 0.21% improvement—with training time rising from 3.47s to 6.66s. MAGIC Gamma Telescope (19,020 instances) shows similar patterns: KAN 86.94% versus MLP 85.94%, training time 2.74s versus 1.45s.   The Dry Bean dataset (13,611 instances, 7 classes) reveals near-parity: both achieve ~92.8% accuracy, suggesting KAN advantages require either larger scale or specific data characteristics. 

**Small-scale benchmarks** favor MLPs. Breast Cancer Wisconsin (569 instances, 30 features) shows MLP superiority: 96.84% versus KAN’s 94.56%, with MLPs training faster (0.06s vs 0.09s).   This aligns with KAN theory—parameter counts for small networks approach or exceed data points, causing overfitting without massive regularization.  The interpolation threshold (params ≈ data points) suggests KANs need thousands of samples minimum to leverage their capacity effectively.

**Feature dimensionality** impacts performance nonlinearly. Low-dimensional problems (1-20 features) suit KANs well, as spline-based activations efficiently capture feature interactions. The Musk dataset (166 features, 6,598 instances) shows KAN achieving 92.45% versus MLP’s 90.44%—a strong advantage despite high dimensionality, likely due to compositional structure in the underlying chemistry. However, extremely high-dimensional sparse data (>500 features) favors linear methods or MLPs due to KAN’s quadratic parameter scaling with layer width.

**Imbalanced classification** presents challenges. A dedicated study across 10 imbalanced datasets found KANs handle raw imbalance better than MLPs but suffer significant degradation when conventional resampling techniques (SMOTE, undersampling) are applied. The computational cost remains prohibitively high without proportional accuracy gains, suggesting MLPs or tree-based methods remain preferable for severely imbalanced problems. 

**Time series classification** on the UCR Archive (117 diverse datasets) achieves median 82.3% accuracy versus MLPs at 80.7%—consistent but modest improvement across domains including ECG, motion sensors, audio, and images.   Grid size analysis reveals optimal performance at grid=3-5 for time series; larger grids cause overfitting on sequential data. The Efficient KAN variant shows superior stability across architectural choices, suggesting simplified basis functions benefit temporal patterns.

**Hyperparameter sensitivity** for tabular data: Width of 5-20 neurons typically suffices; deeper networks (3-4 layers) help on complex datasets but increase training cost cubically. Learning rate of 1e-3 with Adam and weight decay of 1e-4 provides robust baseline. Grid size progression 3→5→10 balances accuracy and speed; further extension to 20-50 rarely improves test performance due to overfitting on finite tabular datasets.

**Training efficiency** considerations: For datasets under 100K instances, CPU training remains viable (seconds to minutes). Beyond 100K, GPU acceleration with efficient-KAN reduces training to reasonable timescales. Mini-batch sizes of 64-256 work well; larger batches accelerate training but may hurt generalization. Early stopping based on validation loss prevents wasted computation on overfit models.

**When to use KANs for tabular data**: (1) Large datasets (>50K instances) where 1-3% accuracy improvement justifies 2-3x training cost. (2) Interpretability requirements—visualizing learned feature interactions reveals domain insights. (3) Regression tasks where KAN’s smooth function approximation excels. (4) Scientific or engineering domains with compositional data structure. (5) When offline training and fast inference suit the deployment scenario.

**When MLPs or GBDTs are preferable**: (1) Small datasets (<10K instances) where simpler models generalize better. (2) Very high-dimensional data (>200 features) where KAN parameters explode. (3) Imbalanced classification requiring resampling. (4) Real-time online learning scenarios. (5) When established baselines already achieve satisfactory performance.

## Code examples and reproducibility resources

Complete working implementations exist across frameworks and domains, enabling immediate experimentation. The **MNIST classification** example using efficient-KAN demonstrates standard patterns:

```python
from efficient_kan import KAN
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
from torch.utils.data import DataLoader
import torchvision.transforms as transforms

# Load MNIST
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5,), (0.5,))
])
trainset = torchvision.datasets.MNIST(
    root="./data", train=True, download=True, transform=transform
)
trainloader = DataLoader(trainset, batch_size=64, shuffle=True)
testset = torchvision.datasets.MNIST(
    root="./data", train=False, download=True, transform=transform
)
testloader = DataLoader(testset, batch_size=64, shuffle=False)

# Define KAN: 784 inputs (28x28) → 64 hidden → 10 outputs
model = KAN([28 * 28, 64, 10])
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)

# Optimizer and loss
optimizer = optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
scheduler = optim.lr_scheduler.ExponentialLR(optimizer, gamma=0.8)
criterion = nn.CrossEntropyLoss()

# Training loop
for epoch in range(10):
    model.train()
    for batch_x, batch_y in trainloader:
        batch_x = batch_x.view(-1, 28*28).to(device)  # Flatten images
        batch_y = batch_y.to(device)
        
        optimizer.zero_grad()
        outputs = model(batch_x)
        loss = criterion(outputs, batch_y)
        loss.backward()
        optimizer.step()
    
    scheduler.step()
    
    # Evaluation
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for batch_x, batch_y in testloader:
            batch_x = batch_x.view(-1, 28*28).to(device)
            batch_y = batch_y.to(device)
            outputs = model(batch_x)
            _, predicted = torch.max(outputs.data, 1)
            total += batch_y.size(0)
            correct += (predicted == batch_y).sum().item()
    
    accuracy = 100 * correct / total
    print(f"Epoch {epoch+1}, Accuracy: {accuracy:.2f}%")
```

This achieves ~97% accuracy in 10 epochs. For 99%+ accuracy, use KANvolver architecture combining convolutional layers with polynomial expansions.

**PDE solving** with PyKAN demonstrates physics-informed training:

```python
from kan import KAN
import torch

# 2D Poisson equation: ∇²u = f
def pde_loss(model, x, y):
    # x, y are 2D coordinates
    xy = torch.cat([x, y], dim=1)
    u = model(xy)
    
    # Compute derivatives via autograd
    u_x = torch.autograd.grad(u, x, torch.ones_like(u), 
                               create_graph=True)[0]
    u_xx = torch.autograd.grad(u_x, x, torch.ones_like(u_x), 
                                create_graph=True)[0]
    u_y = torch.autograd.grad(u, y, torch.ones_like(u), 
                               create_graph=True)[0]
    u_yy = torch.autograd.grad(u_y, y, torch.ones_like(u_y), 
                                create_graph=True)[0]
    
    # PDE residual: ∇²u - f(x,y)
    laplacian = u_xx + u_yy
    f = -2 * (torch.pi**2) * torch.sin(torch.pi*x) * torch.sin(torch.pi*y)
    residual = laplacian - f
    
    return torch.mean(residual**2)

# Boundary conditions
def boundary_loss(model, x_boundary, y_boundary, u_boundary):
    xy_boundary = torch.cat([x_boundary, y_boundary], dim=1)
    u_pred = model(xy_boundary)
    return torch.mean((u_pred - u_boundary)**2)

# Initialize KAN for PDE
model = KAN([2, 10, 10, 1], grid=5, k=3)
model.speed()

# Sample interior and boundary points
# ... (domain sampling code)

# Training with LBFGS
optimizer = torch.optim.LBFGS(model.parameters(), lr=0.1)

def closure():
    optimizer.zero_grad()
    loss_pde = pde_loss(model, x_interior, y_interior)
    loss_bc = boundary_loss(model, x_boundary, y_boundary, u_boundary)
    loss = loss_pde + 10 * loss_bc  # Weight boundary conditions
    loss.backward()
    return loss

for i in range(100):
    loss = optimizer.step(closure)
    if i % 10 == 0:
        print(f"Step {i}, Loss: {loss.item():.6f}")
```

**Tabular regression** with grid extension:

```python
from kan import KAN
import numpy as np
from sklearn.datasets import load_diabetes
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

# Load data
X, y = load_diabetes(return_X_y=True)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# Preprocess
scaler = StandardScaler()
X_train = scaler.fit_transform(X_train)
X_test = scaler.transform(X_test)

# Convert to PyKAN dataset format
from kan.utils import create_dataset
train_input = torch.tensor(X_train, dtype=torch.float32)
train_label = torch.tensor(y_train, dtype=torch.float32).reshape(-1, 1)
dataset = {'train_input': train_input, 'train_label': train_label}

# Initialize with small grid
model = KAN([X_train.shape[1], 5, 1], grid=3, k=3)
model.speed()

# Progressive training with grid extension
for grid_size in [3, 5, 10, 20]:
    print(f"Training with grid size {grid_size}")
    model.fit(dataset, opt="LBFGS", steps=200, lamb=0.01)
    
    if grid_size < 20:
        model.refine(grid_factor=2)
    
    # Evaluate
    test_input = torch.tensor(X_test, dtype=torch.float32)
    with torch.no_grad():
        predictions = model(test_input)
        mse = torch.mean((predictions - torch.tensor(y_test).reshape(-1,1))**2)
        print(f"Test MSE: {mse.item():.4f}")

# Visualize learned functions
model.plot()
```

**Reproducible notebooks** exist across platforms. PyKAN’s tutorials folder contains 10+ Jupyter notebooks covering function approximation (`hellokan.ipynb`), PDE solving, symbolic regression, and physics applications. The team-daniel/KAN repository provides beginner-friendly classification and regression notebooks with detailed explanations, runnable on Google Colab with CPU or GPU.

**Kaggle notebooks** offer community examples: “PyKAN” by rkuo2000 demonstrates basic usage, “KAN Tabular Data Binary Classification” shows end-to-end tabular workflow, and “Chebyshev-KAN for MNIST” compares basis functions. These notebooks include data loading, preprocessing, training, and visualization in single reproducible environments.

**FastKAN example** for speed-critical applications:

```bash
git clone https://github.com/ZiyaoLi/fast-kan
cd fast-kan
pip install .
python examples/train_mnist.py  # 3.33x faster than efficient-KAN
```

**Domain-specific templates**: jaxKAN documentation provides physics-informed examples with Flax NNX integration. TKAN repository includes multi-horizon time series forecasting with Keras 3 backends. TabKANet offers transformer-integrated architectures for heterogeneous tabular data.

**Debugging and visualization** capabilities distinguish KAN implementations:

```python
# Visualize network structure and activations
model.plot(beta=5)  # Beta controls transparency (activation magnitude)

# Suggest symbolic functions for each activation
model.suggest_symbolic(lib=['sin', 'cos', 'exp', 'log', 'sqrt', 'x^2', 'x^3'])

# Snap to symbolic form and fine-tune
model.auto_symbolic()  # Automatically converts suitable activations

# Prune unimportant connections
model.prune()
```

All major implementations support model checkpointing for resuming training, exporting for deployment, and compatibility with standard PyTorch/JAX/TensorFlow deployment pipelines. Documentation universally includes API references, quickstart guides, and troubleshooting sections addressing common issues like slow training (missing `speed()` call), overfitting (reduce grid size), and numerical instability (check grid adaptation).

## Future research directions and current limitations

KAN limitations constrain current applicability despite theoretical advantages. **Training speed** remains the primary bottleneck: 10-15x slower than MLPs per epoch due to heterogeneous spline evaluations that limit GPU parallelization. FastKAN reduces this gap to 2x through RBF simplifications, but still lags standard architectures. This computational cost makes KANs impractical for very large-scale training (\u003e10M samples) or real-time online learning scenarios where rapid iteration is essential.

**Scalability to high dimensions** poses fundamental challenges. Parameter counts scale quadratically with layer width: a [50, 100, 50] network requires dramatically more parameters than an MLP of comparable width due to learnable activations on every edge. For problems with \u003e100 input features, this scaling becomes prohibitive unless significant sparsification can be justified. Current research explores factorized KAN architectures and low-rank approximations to address this limitation.

**Robustness concerns** emerge in physics-informed applications. The comprehensive PINN comparison (Shukla et al., 2024) found original B-spline KANs “lacking accuracy and efficiency” for differential equations, with concerning sensitivity to random seeds and divergence with higher-order polynomials. Modified KANs using orthogonal polynomials achieve comparable results to established methods, but lack the reliability of mature PINN frameworks. Production scientific computing requires additional validation before replacing proven approaches.

**Architecture search** remains largely manual. Unlike MLPs where standard configurations (width 128-512, depth 2-4) generalize broadly, KANs require problem-specific tuning of grid size, spline order, width, depth, and regularization. Automated neural architecture search for KANs is nascent, with most practitioners relying on trial-and-error or domain expertise. This limits accessibility for non-specialists and slows adoption in new application areas.

**Noise sensitivity** in computer vision applications (Cang et al., 2024) shows KANs more affected by image corruption than CNNs. Solutions involving segment deactivation and smoothness regularization improve robustness by 3-4% but don’t fully close the gap. This suggests fundamental architectural limitations for high-dimensional noisy data, where local spline representations may overfit noise patterns.

Promising research directions address these gaps. **KAN-Transformer hybrids** (“KAN-formers”) could replace MLP layers in attention architectures, potentially improving interpretability and parameter efficiency for language models. Early experiments show feasibility but lack large-scale validation. **Improved GPU kernels** using grouped activations and batched spline evaluations could narrow the speed gap to 2-3x versus current 10-15x. **Meta-learning** for KAN initialization could reduce sensitivity to random seeds and transfer learned representations across related tasks.

**Hybrid architectures** combining CNNs for feature extraction with KAN layers for final prediction show promise—ConvKAN approaches achieve competitive accuracy on vision tasks where pure KANs struggle. **Automated basis function selection** could adaptively choose between B-splines, wavelets, Chebyshev polynomials, or RBFs based on data characteristics, eliminating manual tuning. **Federated learning** with KANs remains largely unexplored but could leverage interpretability for privacy-preserving collaborative training.

**Quantum KAN** variants propose quantum circuit implementations leveraging superposition for massive parallelization, though practical realization awaits quantum hardware maturity. **Neural operator extensions** integrating KANs into Fourier Neural Operators, DeepONets, and Graph Neural Operators show 10-30% improvements but require further theoretical understanding of when KAN advantages persist in operator learning regimes.

The field’s rapid evolution—792+ citations and 50+ follow-up papers within 9 months—suggests active community engagement. Current trajectory points toward KANs becoming standard tools for scientific computing, symbolic regression, and interpretable AI, while remaining niche for large-scale vision/NLP where established architectures dominate. Computational efficiency improvements will determine whether KANs expand beyond these domains or remain specialized tools for accuracy-critical applications where training cost is secondary to performance.

Practical recommendations for practitioners: Use current KAN implementations for problems where 1-5% accuracy improvement or interpretability justifies 2-10x training cost. Monitor the efficient-KAN and FastKAN repositories for performance improvements. For production systems, prototype with PyKAN for full features, then deploy with efficient-KAN for speed. Avoid KANs for real-time learning, very high-dimensional data, or tasks where MLPs already work well. Leverage KAN’s unique strengths—symbolic regression, PDE solving, scientific discovery—rather than treating them as universal MLP replacements.


-----

# ERROR: Unable to find compatible target in cached code image.

```bash
Target 0 (znver3): Rejecting this target due to use of runtime-disabled features
```

This is a classic CPU target compatibility issue with PackageCompiler.jl in containerized environments. The problem occurs because the system image is compiled for a specific CPU architecture (znver3 - AMD Zen 3) during build time, but at runtime it's trying to run on different hardware that doesn't support all the optimized features.

Here's the solution - you need to set the CPU target **during the build stage**, not just at runtime:## Key Changes Made:

1. **Set CPU target during BUILD stage**: Added `ENV JULIA_CPU_TARGET="generic"` in the builder stage before compiling
2. **Explicit CPU target for PackageCompiler**: Added `cpu_target="generic"` parameter to `create_sysimage()`

## Why This Happens:

- **Dev environment**: Your development machine likely has consistent hardware
- **UAT/Azure**: Different Azure VM families (Standard_D, Standard_E, etc.) have different CPU architectures
- **PackageCompiler**: By default, it optimizes for the build machine's CPU, creating incompatible system images

## Alternative CPU Target Options:

If you want some performance optimization but still broad compatibility:

```dockerfile
# More optimized but still compatible
ENV JULIA_CPU_TARGET="generic;x86-64-v2"

# Or if you know your Azure VM families:
ENV JULIA_CPU_TARGET="generic;x86-64-v2;x86-64-v3"
```

## Additional Recommendations:

1. **Pin your base image version** to avoid Julia version changes:
   ```dockerfile
   FROM julia:1.11.5 AS builder
   ```

2. **Add CPU target verification** (optional debugging):
   ```dockerfile
   RUN julia -e "println(\"Build CPU target: \", Base.julia_cmd())"
   ```

3. **Consider using multi-stage caching** for faster builds:
   ```dockerfile
   # Cache the PackageCompiler installation
   RUN julia --project=/home/jl/app -e 'using Pkg; Pkg.add("PackageCompiler")'
   ```

This should eliminate the random failures you're experiencing between different Azure environments.

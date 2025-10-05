# Lix Packaging

Step-by-step guide to using Lix for packaging a Linux application, showcasing its most powerful features.​​​​​​​​​​​​​​​​

## Complete Lix Packaging Tutorial: From Zero to Distribution

I’ll walk you through packaging a real application with Lix, demonstrating its most powerful features for distributing Linux software.

## Step 1: Install Lix

```bash
# Install Lix (single command)
curl -sSf -L https://install.lix.systems/lix | sh -s -- install

# Enable flakes (modern Lix features)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Verify installation
nix --version  # Should show "nix (Lix, like Nix)"
```

## Step 2: Create a Simple Application

Let’s package a real C program. Create a project directory:

```bash
mkdir my-hello-app
cd my-hello-app
```

Create `hello.c`:

```c
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    const char *name = (argc > 1) ? argv[1] : "World";
    printf("Hello, %s! Built with Lix.\n", name);
    return 0;
}
```

Create `Makefile`:

```makefile
CC ?= gcc
CFLAGS ?= -O2 -Wall
PREFIX ?= /usr/local

all: hello

hello: hello.c
	$(CC) $(CFLAGS) -o hello hello.c

install: hello
	mkdir -p $(PREFIX)/bin
	install -m 755 hello $(PREFIX)/bin/

clean:
	rm -f hello

.PHONY: all install clean
```

## Step 3: Create a Flake (The Modern Lix Way)

Create `flake.nix` - this is the heart of reproducible packaging:

```nix
{
  description = "My Hello App - A reproducible Linux application";

  # Pin exact versions of dependencies
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      # Systems to support
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      
      # Helper to generate attributes for all systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      
      # Nixpkgs instantiated for each system
      pkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      # FEATURE 1: Reproducible package builds
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "my-hello-app";
            version = "1.0.0";

            src = ./.;

            nativeBuildInputs = [ pkgs.gcc pkgs.gnumake ];

            buildPhase = ''
              make
            '';

            installPhase = ''
              make install PREFIX=$out
            '';

            meta = with pkgs.lib; {
              description = "A hello world application built with Lix";
              license = licenses.mit;
              platforms = platforms.all;
              maintainers = [ "your-name" ];
            };
          };

          # FEATURE 2: Static binary (portable across Linux distros)
          static = pkgs.pkgsStatic.stdenv.mkDerivation {
            pname = "my-hello-app-static";
            version = "1.0.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.gcc pkgs.gnumake ];
            buildPhase = "make CFLAGS='-O2 -Wall -static'";
            installPhase = "make install PREFIX=$out";
          };
        }
      );

      # FEATURE 3: Development environment (reproducible dev setup)
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              gcc
              gnumake
              gdb
              valgrind
              clang-tools  # For clang-format, clang-tidy
            ];

            shellHook = ''
              echo "🚀 Development environment loaded!"
              echo "Available tools: gcc, make, gdb, valgrind, clang-format"
              echo ""
              echo "Commands:"
              echo "  make        - Build the application"
              echo "  make clean  - Clean build artifacts"
              echo "  nix build   - Build with Lix"
              echo ""
            '';
          };
        }
      );

      # FEATURE 4: Overlay (integrate with other Nix packages)
      overlays.default = final: prev: {
        my-hello-app = self.packages.${prev.system}.default;
      };
    };
}
```

## Step 4: Initialize Git (Required for Flakes)

Flakes only copy files tracked by git to maximize reproducibility :

```bash
git init
git add .
git commit -m "Initial commit"
```

## Step 5: Build and Test Your Package

```bash
# Build the package (completely reproducible)
nix build

# The result is a symlink to the Nix store
ls -l result/bin/hello

# Run your application
./result/bin/hello
./result/bin/hello "Lix User"

# Build the static version (portable binary)
nix build .#static
file result/bin/hello  # Shows: statically linked
```

## Step 6: Enter Development Environment

```bash
# Enter the reproducible dev shell
nix develop

# Now you have all dev tools available
make
./hello
make clean
```

Anyone on your team can run `nix develop` and get **exactly** the same environment!

## Step 7: Key Lix Features in Action

### Feature 1: Binary Caching (Speed)

```bash
# Build generates a cache automatically
nix build --print-build-logs

# Share your cache with the team (using Cachix)
# First time setup:
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use my-company  # Use your cache
cachix push my-company $(nix build --print-out-paths)
```

### Feature 2: Multi-Platform Builds

```bash
# Build for different architectures
nix build .#packages.x86_64-linux.default
nix build .#packages.aarch64-linux.default  # ARM64

# Cross-compile from x86_64 to ARM
nix build --system aarch64-linux
```

### Feature 3: Dependency Pinning (Reproducibility)

```bash
# Lock file ensures everyone gets same dependencies
cat flake.lock  # Generated automatically

# Update dependencies explicitly
nix flake update

# Or update just one input
nix flake lock --update-input nixpkgs
```

### Feature 4: Multiple Package Variants

Add to your `flake.nix` outputs:

```nix
packages = forAllSystems (system:
  let
    pkgs = pkgsFor.${system};
    commonAttrs = {
      pname = "my-hello-app";
      version = "1.0.0";
      src = ./.;
      nativeBuildInputs = [ pkgs.gcc pkgs.gnumake ];
    };
  in
  {
    # Production build
    default = pkgs.stdenv.mkDerivation (commonAttrs // {
      buildPhase = "make CFLAGS='-O3 -Wall'";
      installPhase = "make install PREFIX=$out";
    });

    # Debug build
    debug = pkgs.stdenv.mkDerivation (commonAttrs // {
      buildPhase = "make CFLAGS='-g -O0 -Wall'";
      installPhase = "make install PREFIX=$out";
    });

    # Static binary (for distribution)
    static = pkgs.pkgsStatic.stdenv.mkDerivation (commonAttrs // {
      buildPhase = "make CFLAGS='-O3 -Wall -static'";
      installPhase = "make install PREFIX=$out";
    });
  }
);
```

Build different variants:

```bash
nix build .#default  # Production
nix build .#debug    # With debug symbols
nix build .#static   # Portable static binary
```

## Step 8: Distribution Strategies

### Option A: Direct Installation (Users with Lix)

Users can install directly from your repo:

```bash
# Install from GitHub
nix profile install github:yourname/my-hello-app

# Or from local flake
nix profile install .
```

### Option B: Standalone Binary

```bash
# Build portable static binary
nix build .#static

# Copy to users (works on any Linux)
cp result/bin/hello ~/my-hello-portable
```

### Option C: Docker Image

Add to `flake.nix`:

```nix
packages = forAllSystems (system: {
  # ... existing packages ...
  
  docker = pkgs.dockerTools.buildLayeredImage {
    name = "my-hello-app";
    tag = "latest";
    contents = [ self.packages.${system}.default ];
    config = {
      Cmd = [ "${self.packages.${system}.default}/bin/hello" ];
    };
  };
});
```

Build and load:

```bash
nix build .#docker
docker load < result
docker run my-hello-app:latest
```

## Step 9: Advanced - Package with Dependencies

Here’s a more realistic example with external libraries:

```nix
packages.default = pkgs.stdenv.mkDerivation {
  pname = "my-app";
  version = "1.0.0";
  src = ./.;

  # Build-time dependencies
  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
  ];

  # Runtime dependencies
  buildInputs = with pkgs; [
    openssl
    sqlite
    curl
    zlib
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DENABLE_TESTS=ON"
  ];

  # Run tests
  doCheck = true;

  meta = with pkgs.lib; {
    description = "Production application";
    license = licenses.mit;
    platforms = platforms.linux;
  };
};
```

## Step 10: Best Practices Summary

1. **Always use flakes** - Modern, reproducible, pinned dependencies
1. **Commit flake.lock** - Ensures team uses same dependencies
1. **Use `nix develop`** - Consistent dev environments across team
1. **Provide multiple outputs** - debug, release, static variants
1. **Set up binary caching** - Speed up CI/CD and team builds
1. **Pin nixpkgs version** - Stability for production
1. **Test on CI** - Use `nix build` in GitHub Actions/GitLab CI
1. **Document in README** - Show `nix build` and `nix develop` commands

## Why This Matters for Linux Distribution

✅ **Reproducibility** - Build once, works everywhere, forever  
✅ **No “works on my machine”** - `flake.lock` ensures identical builds  
✅ **No system pollution** - Everything in `/nix/store`, isolated  
✅ **Multi-distro support** - One package for Ubuntu, Fedora, Arch, etc.  
✅ **Dependency hell solved** - Lix manages everything  
✅ **Rollback capability** - Bad update? Instant rollback  
✅ **Development parity** - Dev and prod use same build  
✅ **Binary caching** - Fast builds via shared cache

Our users with Lix can install with one command, you can distribute static binaries, or create Docker images - all from the same reproducible source!
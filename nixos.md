# NixOS 

A real-world guide to NixOS for developers, showing how to build a fully automated, reproducible development workstation.​​​​​​​​​​​​​​​​

# Complete NixOS Developer Guide: From Zero to Fully Automated Dev Environment

This guide shows you how to build a **production-ready, reproducible development workstation** using NixOS with modern best practices.

## 🎯 What You’ll Build

A fully automated developer workstation with:

- ✅ Declarative system configuration (reproducible across machines)
- ✅ User environment management (dotfiles, tools, settings)
- ✅ Development shells per project
- ✅ System services (Docker, PostgreSQL, Redis)
- ✅ Multi-machine sync capability
- ✅ Instant rollback on any change

-----

## Part 1: Initial NixOS Setup

### Step 1: Install NixOS

Download from <https://nixos.org/download> and install. During installation, choose a username (we’ll use `developer` in examples).

### Step 2: Enable Flakes

Edit `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  # Enable flakes system-wide
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  networking.hostName = "dev-machine";
  networking.networkmanager.enable = true;
  
  time.timeZone = "America/New_York";
  
  users.users.developer = {
    isNormalUser = true;
    description = "Developer";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
  };
  
  system.stateVersion = "24.05";
}
```

Apply:

```bash
sudo nixos-rebuild switch
```

-----

## Part 2: Modern Flake-Based Configuration

### Step 3: Create Your Configuration Repository

```bash
# Create configuration directory
sudo mkdir -p /etc/nixos
cd /etc/nixos
sudo git init
```

### Step 4: Create the Master Flake

Create `/etc/nixos/flake.nix`:

```nix
{
  description = "Developer workstation NixOS configuration";

  inputs = {
    # Stable nixpkgs for system
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    
    # Unstable for latest packages when needed
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Home Manager for user environment
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";  # or "aarch64-linux" for ARM
      
      # Overlay to add unstable packages
      overlays = [
        (final: prev: {
          unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        })
      ];
      
    in {
      nixosConfigurations = {
        # Your hostname here
        dev-machine = nixpkgs.lib.nixosSystem {
          inherit system;
          
          specialArgs = { inherit inputs; };
          
          modules = [
            # Import hardware config
            ./hardware-configuration.nix
            
            # Main system configuration
            ./configuration.nix
            
            # Apply overlays
            { nixpkgs.overlays = overlays; }
            
            # Home Manager as NixOS module
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.developer = import ./home.nix;
              
              # Pass inputs to home-manager
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
      };
    };
}
```

### Step 5: Enhanced System Configuration

Create `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # =====================================================
  # SYSTEM PACKAGES & ENVIRONMENT
  # =====================================================
  
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    tmux
    unzip
    rsync
  ];

  # =====================================================
  # DEVELOPMENT SERVICES
  # =====================================================
  
  # Docker for containerized development
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  
  # PostgreSQL database service
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    enableTCPIP = true;
    
    # Development-friendly authentication
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  user      address        auth-method
      local all       all                      trust
      host  all       all       127.0.0.1/32   trust
      host  all       all       ::1/128        trust
    '';
    
    # Create databases on first start
    ensureDatabases = [ "dev_db" "test_db" ];
    
    ensureUsers = [
      {
        name = "developer";
        ensureDBOwnership = true;
      }
    ];
  };
  
  # Redis for caching
  services.redis.servers."dev" = {
    enable = true;
    port = 6379;
  };
  
  # =====================================================
  # DOCKER CONTAINERS (Declarative)
  # =====================================================
  
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      # MongoDB for NoSQL development
      mongodb = {
        image = "mongo:7";
        ports = [ "27017:27017" ];
        environment = {
          MONGO_INITDB_ROOT_USERNAME = "admin";
          MONGO_INITDB_ROOT_PASSWORD = "devpassword";
        };
        volumes = [ "mongodb_data:/data/db" ];
      };
      
      # RabbitMQ message broker
      rabbitmq = {
        image = "rabbitmq:3-management";
        ports = [ 
          "5672:5672"   # AMQP
          "15672:15672" # Management UI
        ];
        environment = {
          RABBITMQ_DEFAULT_USER = "admin";
          RABBITMQ_DEFAULT_PASS = "admin";
        };
      };
    };
  };

  # =====================================================
  # NETWORKING & SECURITY
  # =====================================================
  
  networking.hostName = "dev-machine";
  networking.networkmanager.enable = true;
  
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 3000 8080 8000 5432 ];  # Common dev ports
  };

  # =====================================================
  # USER CONFIGURATION
  # =====================================================
  
  users.users.developer = {
    isNormalUser = true;
    description = "Developer User";
    extraGroups = [ 
      "wheel"          # sudo access
      "networkmanager" # network control
      "docker"         # docker without sudo
      "video"          # GPU access
      "audio"          # audio devices
    ];
    shell = pkgs.zsh;  # Set default shell
  };

  # =====================================================
  # SYSTEM-WIDE PROGRAMS
  # =====================================================
  
  programs.zsh.enable = true;
  
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
    };
  };

  # =====================================================
  # NIX SETTINGS
  # =====================================================
  
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      
      # Trusted users for binary cache
      trusted-users = [ "root" "developer" ];
      
      # Substituters for faster builds
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    
    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # =====================================================
  # BOOT & HARDWARE
  # =====================================================
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Kernel parameters for development
  boot.kernelParams = [ "quiet" ];

  # =====================================================
  # LOCALIZATION
  # =====================================================
  
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # =====================================================
  # STATE VERSION (Don't change)
  # =====================================================
  
  system.stateVersion = "24.05";
}
```

-----

## Part 3: User Environment with Home Manager

### Step 6: Create Home Manager Configuration

Create `/etc/nixos/home.nix`:

```nix
{ config, pkgs, inputs, ... }:

{
  # =====================================================
  # HOME MANAGER BASICS
  # =====================================================
  
  home.username = "developer";
  home.homeDirectory = "/home/developer";
  home.stateVersion = "24.05";
  
  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # =====================================================
  # USER PACKAGES
  # =====================================================
  
  home.packages = with pkgs; [
    # Development Tools
    gcc
    gnumake
    cmake
    pkg-config
    
    # Programming Languages
    python312
    python312Packages.pip
    python312Packages.virtualenv
    nodejs_20
    go
    rustc
    cargo
    
    # CLI Tools
    fzf
    ripgrep
    fd
    bat
    exa
    jq
    yq
    httpie
    
    # Terminal Multiplexer
    tmux
    
    # Version Control
    git
    gh          # GitHub CLI
    lazygit     # TUI for git
    
    # Kubernetes & Cloud
    kubectl
    k9s
    terraform
    
    # Database CLIs
    postgresql
    redis
    mongosh
    
    # Editors
    neovim
    vscode
    
    # Unstable packages (latest versions)
    unstable.zed-editor
    unstable.bun
  ];

  # =====================================================
  # GIT CONFIGURATION
  # =====================================================
  
  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "[email protected]";
    
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;
      diff.colorMoved = "zebra";
      
      # Better diffs
      core.pager = "delta";
    };
    
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Dracula";
      };
    };
    
    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      ci = "commit";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
    };
  };

  # =====================================================
  # ZSH CONFIGURATION
  # =====================================================
  
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      ll = "ls -lah";
      ".." = "cd ..";
      "..." = "cd ../..";
      
      # NixOS shortcuts
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#dev-machine";
      update = "sudo nix flake update /etc/nixos";
      clean = "sudo nix-collect-garbage -d";
      
      # Development shortcuts
      dc = "docker-compose";
      k = "kubectl";
      tf = "terraform";
      
      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
    };
    
    initExtra = ''
      # Custom prompt
      autoload -Uz vcs_info
      precmd() { vcs_info }
      zstyle ':vcs_info:git:*' formats '%b '
      setopt PROMPT_SUBST
      PROMPT='%F{green}%n@%m%f:%F{blue}%~%f %F{red}''${vcs_info_msg_0_}%f$ '
      
      # FZF keybindings
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
      
      # Development environment info
      echo "🚀 Developer Environment Ready!"
      echo "Services: PostgreSQL (5432), Redis (6379), Docker"
    '';
    
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "kubectl" "terraform" ];
      theme = "robbyrussell";
    };
  };

  # =====================================================
  # TMUX CONFIGURATION
  # =====================================================
  
  programs.tmux = {
    enable = true;
    shortcut = "a";
    terminal = "screen-256color";
    historyLimit = 10000;
    
    extraConfig = ''
      # Better splitting
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %
      
      # Vim-like pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      
      # Enable mouse
      set -g mouse on
      
      # Status bar
      set -g status-style bg=black,fg=white
    '';
  };

  # =====================================================
  # NEOVIM CONFIGURATION
  # =====================================================
  
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    
    plugins = with pkgs.vimPlugins; [
      vim-nix
      vim-fugitive
      fzf-vim
      nerdtree
      vim-airline
      vim-airline-themes
    ];
    
    extraConfig = ''
      set number
      set relativenumber
      set expandtab
      set tabstop=2
      set shiftwidth=2
      syntax on
      
      " NERDTree toggle
      nnoremap <C-n> :NERDTreeToggle<CR>
    '';
  };

  # =====================================================
  # VSCODE CONFIGURATION
  # =====================================================
  
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      ms-python.python
      ms-vscode.cpptools
      golang.go
      rust-lang.rust-analyzer
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint
    ];
    
    userSettings = {
      "editor.fontSize" = 14;
      "editor.tabSize" = 2;
      "editor.formatOnSave" = true;
      "files.autoSave" = "onFocusChange";
      "terminal.integrated.shell.linux" = "${pkgs.zsh}/bin/zsh";
    };
  };

  # =====================================================
  # ENVIRONMENT VARIABLES
  # =====================================================
  
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BROWSER = "firefox";
    
    # Development paths
    GOPATH = "$HOME/go";
    CARGO_HOME = "$HOME/.cargo";
    
    # PostgreSQL connection for quick access
    DATABASE_URL = "postgresql://developer@localhost:5432/dev_db";
  };

  # =====================================================
  # XDG DIRECTORIES
  # =====================================================
  
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    videos = "$HOME/Videos";
    templates = "$HOME/Templates";
    publicShare = "$HOME/Public";
  };
}
```

-----

## Part 4: Apply Your Configuration

### Step 7: Build and Switch

```bash
# Add files to git (required for flakes)
cd /etc/nixos
sudo git add .
sudo git commit -m "Initial flake configuration"

# Build and switch (may take 10-20 minutes first time)
sudo nixos-rebuild switch --flake /etc/nixos#dev-machine

# Reboot to ensure everything loads
sudo reboot
```

-----

## Part 5: Project-Specific Development Shells

### Step 8: Create Per-Project Environments

Create `~/projects/my-web-app/flake.nix`:

```nix
{
  description = "Web application development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Node.js development
          nodejs_20
          nodePackages.typescript
          nodePackages.eslint
          nodePackages.prettier
          
          # Database
          postgresql
          
          # Testing
          cypress
        ];
        
        shellHook = ''
          echo "🔥 Web App Development Environment"
          echo ""
          echo "Node: $(node --version)"
          echo "npm: $(npm --version)"
          echo ""
          echo "Database: postgresql://localhost:5432/dev_db"
          echo ""
          
          # Auto-start PostgreSQL if not running
          if ! pg_isready -q; then
            echo "⚠️  PostgreSQL is not running. Start with: sudo systemctl start postgresql"
          fi
          
          # Set up node_modules if needed
          if [ ! -d "node_modules" ]; then
            echo "📦 Installing dependencies..."
            npm install
          fi
        '';
      };
    };
}
```

Enter the environment:

```bash
cd ~/projects/my-web-app
nix develop
```

### Step 9: Python Data Science Environment

Create `~/projects/data-analysis/flake.nix`:

```nix
{
  description = "Python data science environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      python-with-packages = pkgs.python312.withPackages (ps: with ps; [
        pandas
        numpy
        scipy
        matplotlib
        seaborn
        jupyter
        scikit-learn
        tensorflow
        torch
        requests
        sqlalchemy
        psycopg2
      ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          python-with-packages
          pkgs.postgresql
        ];
        
        shellHook = ''
          echo "🐍 Python Data Science Environment"
          echo ""
          python --version
          echo ""
          echo "Available packages:"
          echo "  - pandas, numpy, scipy"
          echo "  - matplotlib, seaborn"
          echo "  - jupyter (run: jupyter lab)"
          echo "  - scikit-learn, tensorflow, pytorch"
          echo ""
          echo "Start Jupyter Lab:"
          echo "  jupyter lab --no-browser"
        '';
      };
    };
}
```

-----

## Part 6: Multi-Machine Synchronization

### Step 10: Sync Across Machines

Push your config to GitHub:

```bash
cd /etc/nixos
sudo git remote add origin git@github.com:yourusername/nixos-config.git
sudo git push -u origin main
```

On a **new machine**:

```bash
# Install NixOS normally, then:
sudo mv /etc/nixos /etc/nixos.backup
sudo git clone git@github.com:yourusername/nixos-config.git /etc/nixos
cd /etc/nixos

# Update hostname in flake.nix for new machine
sudo vim flake.nix  # Add new machine config

# Apply
sudo nixos-rebuild switch --flake /etc/nixos#new-machine
```

-----

## Part 7: Daily Workflows

### Common Commands

```bash
# System Updates
sudo nix flake update /etc/nixos     # Update all inputs
sudo nixos-rebuild switch --flake /etc/nixos#dev-machine

# Rollback if something breaks
sudo nixos-rebuild switch --rollback

# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Cleanup old generations
sudo nix-collect-garbage -d

# Check what will change
sudo nixos-rebuild dry-build --flake /etc/nixos#dev-machine

# Check service status
systemctl status postgresql
systemctl status docker
systemctl status redis-dev
```

### Updating Packages

```bash
# Update everything
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake .#dev-machine

# Update specific input
sudo nix flake lock --update-input nixpkgs
```

-----

## Part 8: Best Practices

### ✅ DO:

1. **Commit frequently** - Git is required for flakes
1. **Test before pushing** - Use `dry-build` first
1. **Document changes** - Add comments in config files
1. **Use Home Manager** - Keep system and user configs separate
1. **Pin versions** - Use specific nixpkgs versions for stability
1. **Regular garbage collection** - Run `nix-collect-garbage` monthly
1. **Backup `/etc/nixos`** - It’s your entire system config

### ❌ DON’T:

1. **Don’t use `nix-env -i`** - Use declarative packages instead
1. **Don’t edit system files manually** - Put everything in config
1. **Don’t forget `git add`** - Flakes only see committed files
1. **Don’t change `stateVersion`** - Unless you know what you’re doing
1. **Don’t install things globally unnecessarily** - Use project shells

-----

## Part 9: Troubleshooting

### Problem: Build Fails

```bash
# Check for syntax errors
nix flake check /etc/nixos

# Build without switching
sudo nixos-rebuild build --flake /etc/nixos#dev-machine

# See detailed errors
sudo nixos-rebuild switch --flake /etc/nixos#dev-machine --show-trace
```

### Problem: Service Won’t Start

```bash
# Check logs
sudo journalctl -u postgresql -f
sudo journalctl -u docker -f

# Restart service
sudo systemctl restart postgresql
```

### Problem: Out of Disk Space

```bash
# See what's using space
du -sh /nix/store

# Aggressive cleanup
sudo nix-collect-garbage --delete-older-than 7d
sudo nix-store --gc
sudo nix-store --optimize
```

-----

## 🎉 Why This Setup is Powerful

### 1. **Complete Reproducibility**

Your entire system is one Git repository. New machine? Just clone and rebuild.

### 2. **Atomic Upgrades & Rollbacks**

Every change is a generation. Broken update? Rollback in seconds.

### 3. **Isolated Development**

Each project gets its exact dependencies. No version conflicts.

### 4. **Declarative Services**

PostgreSQL, Docker, Redis configured once, working everywhere.

### 5. **Zero Configuration Drift**

Your dev machine matches production. Always.

### 6. **Shareable Development Environments**

`nix develop` gives teammates identical environments instantly.

### 7. **No “Works on My Machine”**

If it builds on your machine, it builds everywhere.

-----

## Next Steps

- Explore [NixOS Options Search](https://search.nixos.org/options)
- Check [Home Manager Options](https://nix-community.github.io/home-manager/options.xhtml)
- Join [NixOS Discourse](https://discourse.nixos.org)
- Browse [Awesome Nix](https://github.com/nix-community/awesome-nix)

**Welcome to NixOS - where infrastructure is code and development environments are declarative!** 🚀​​​​​​​​​​​​​​​​
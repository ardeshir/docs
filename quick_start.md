#!/bin/bash

# Mycelia Network - Quick Start Script

# This gets you running in 5 minutes!

set -e

# Colors for output

RED=’\033[0;31m’
GREEN=’\033[0;32m’
BLUE=’\033[0;34m’
YELLOW=’\033[1;33m’
NC=’\033[0m’ # No Color

echo -e “${BLUE}🍄 Mycelia Network Quick Start${NC}”
echo -e “${YELLOW}Building the future of decentralized social networking!${NC}”
echo “”

# Check prerequisites

echo -e “${BLUE}📋 Checking prerequisites…${NC}”

if ! command -v cargo &> /dev/null; then
echo -e “${RED}❌ Rust/Cargo not found. Please install Rust first:${NC}”
echo “curl –proto ‘=https’ –tlsv1.2 -sSf https://sh.rustup.rs | sh”
exit 1
fi

if ! command -v node &> /dev/null; then
echo -e “${YELLOW}⚠️  Node.js not found. Desktop app won’t work without it.${NC}”
else
echo -e “${GREEN}✅ Node.js found${NC}”
fi

echo -e “${GREEN}✅ Rust/Cargo found${NC}”

# Create workspace

WORKSPACE=“univrs-mycelia-quickstart”
echo -e “${BLUE}📁 Creating workspace: $WORKSPACE${NC}”

if [ -d “$WORKSPACE” ]; then
echo -e “${YELLOW}⚠️  Directory exists. Remove it? (y/n)${NC}”
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
rm -rf “$WORKSPACE”
else
echo “Exiting…”
exit 1
fi
fi

mkdir “$WORKSPACE” && cd “$WORKSPACE”

# Initialize Cargo workspace

echo -e “${BLUE}🔧 Setting up Cargo workspace…${NC}”
cat > Cargo.toml << ‘EOF’
[workspace]
members = [“mycelia-simple”]
resolver = “2”

[workspace.dependencies]
libp2p = “0.53”
tokio = { version = “1.0”, features = [“full”] }
serde = { version = “1.0”, features = [“derive”] }
bincode = “1.3”
blake3 = “1.5”
uuid = { version = “1.0”, features = [“v4”] }
chrono = { version = “0.4”, features = [“serde”] }
env_logger = “0.10”
rand = “0.8”
hex = “0.4”
ed25519-dalek = “2.0”
clap = { version = “4.0”, features = [“derive”] }
EOF

# Create simple node implementation

echo -e “${BLUE}🚀 Creating simple Mycelia node…${NC}”
cargo new –bin mycelia-simple
cd mycelia-simple

# Setup dependencies

cat > Cargo.toml << ‘EOF’
[package]
name = “mycelia-simple”
version = “0.1.0”
edition = “2021”

[dependencies]
libp2p = { workspace = true, features = [“tcp”, “noise”, “yamux”, “gossipsub”, “mdns”] }
tokio = { workspace = true }
serde = { workspace = true }
bincode = { workspace = true }
blake3 = { workspace = true }
uuid = { workspace = true }
chrono = { workspace = true }
env_logger = { workspace = true }
rand = { workspace = true }
hex = { workspace = true }
ed25519-dalek = { workspace = true }
clap = { workspace = true }
EOF

# Create the main implementation

cat > src/main.rs << ‘EOF’
//! Simple Mycelia Network Node
//! A minimal implementation to get started quickly

use libp2p::{
gossipsub::{self, MessageAuthenticity, ValidationMode, Event as GossipEvent},
mdns::{Event as MdnsEvent},
noise, tcp, yamux,
swarm::{NetworkBehaviour, SwarmEvent, SwarmBuilder},
PeerId, Multiaddr,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io;
use tokio::io::AsyncBufReadExt;
use clap::Parser;

#[derive(Parser)]
#[command(name = “mycelia-simple”)]
#[command(about = “A simple Mycelia Network node”)]
struct Args {
#[arg(short, long, default_value = “0”)]
port: u16,

```
#[arg(short, long)]
peer: Option<Multiaddr>,

#[arg(short, long, default_value = "Anonymous")]
name: String,
```

}

#[derive(NetworkBehaviour)]
struct MyceliaBehaviour {
gossipsub: gossipsub::Behaviour,
mdns: libp2p::mdns::tokio::Behaviour,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SimplePost {
id: String,
author: String,
content: String,
timestamp: chrono::DateTime<chrono::Utc>,
}

impl SimplePost {
fn new(author: String, content: String) -> Self {
Self {
id: uuid::Uuid::new_v4().to_string(),
author,
content,
timestamp: chrono::Utc::now(),
}
}
}

struct MyceliaNode {
swarm: libp2p::Swarm<MyceliaBehaviour>,
posts: HashMap<String, SimplePost>,
node_name: String,
}

impl MyceliaNode {
async fn new(node_name: String) -> Result<Self, Box<dyn std::error::Error>> {
let local_key = libp2p::identity::Keypair::generate_ed25519();
let local_peer_id = PeerId::from(local_key.public());

```
    println!("🍄 Local peer id: {local_peer_id}");
    println!("👤 Node name: {node_name}");

    let transport = tcp::tokio::Transport::default()
        .upgrade(libp2p::core::upgrade::Version::V1)
        .authenticate(noise::Config::new(&local_key)?)
        .multiplex(yamux::Config::default())
        .boxed();

    let gossipsub_config = gossipsub::ConfigBuilder::default()
        .heartbeat_interval(std::time::Duration::from_secs(10))
        .validation_mode(ValidationMode::Strict)
        .build()?;

    let gossipsub = gossipsub::Behaviour::new(
        MessageAuthenticity::Signed(local_key),
        gossipsub_config,
    )?;

    let mdns = libp2p::mdns::tokio::Behaviour::new(
        libp2p::mdns::Config::default(),
        local_peer_id,
    )?;

    let behaviour = MyceliaBehaviour { gossipsub, mdns };
    let swarm = SwarmBuilder::with_tokio_executor(transport, behaviour, local_peer_id).build();

    Ok(Self {
        swarm,
        posts: HashMap::new(),
        node_name,
    })
}

async fn start_listening(&mut self, port: u16) -> Result<(), Box<dyn std::error::Error>> {
    let addr = if port == 0 {
        "/ip4/0.0.0.0/tcp/0".parse()?
    } else {
        format!("/ip4/0.0.0.0/tcp/{}", port).parse()?
    };
    
    self.swarm.listen_on(addr)?;
    
    // Subscribe to the main topic
    let topic = gossipsub::IdentTopic::new("mycelia-chat");
    self.swarm.behaviour_mut().gossipsub.subscribe(&topic)?;
    
    Ok(())
}

async fn connect_to_peer(&mut self, addr: Multiaddr) -> Result<(), Box<dyn std::error::Error>> {
    self.swarm.dial(addr)?;
    Ok(())
}

fn publish_post(&mut self, content: String) -> Result<(), Box<dyn std::error::Error>> {
    let post = SimplePost::new(self.node_name.clone(), content);
    let post_id = post.id.clone();
    
    // Serialize and publish
    let message = bincode::serialize(&post)?;
    let topic = gossipsub::IdentTopic::new("mycelia-chat");
    self.swarm.behaviour_mut().gossipsub.publish(topic, message)?;
    
    // Store locally
    self.posts.insert(post_id.clone(), post);
    println!("📤 Published post: {}", post_id);
    
    Ok(())
}

fn handle_received_post(&mut self, post: SimplePost) {
    println!("📨 Received post from {}: {}", post.author, post.content);
    self.posts.insert(post.id.clone(), post);
}

fn list_posts(&self) {
    if self.posts.is_empty() {
        println!("📝 No posts yet. Type 'post <message>' to create one!");
        return;
    }
    
    println!("📚 Recent posts:");
    let mut posts: Vec<_> = self.posts.values().collect();
    posts.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
    
    for (i, post) in posts.iter().take(10).enumerate() {
        let time = post.timestamp.format("%H:%M:%S");
        println!("  {}. [{}] {}: {}", i + 1, time, post.author, post.content);
    }
}

async fn run(&mut self) -> Result<(), Box<dyn std::error::Error>> {
    let mut stdin = tokio::io::BufReader::new(tokio::io::stdin()).lines();
    
    println!("🌐 Mycelia node is running!");
    println!("💬 Commands:");
    println!("  post <message>  - Publish a post");
    println!("  list           - Show recent posts");
    println!("  peers          - Show connected peers");
    println!("  quit           - Exit");
    println!();

    loop {
        tokio::select! {
            line = stdin.next_line() => {
                if let Ok(Some(line)) = line {
                    self.handle_input(line.trim()).await?;
                }
            }
            
            event = self.swarm.select_next_some() => {
                self.handle_swarm_event(event).await?;
            }
        }
    }
}

async fn handle_input(&mut self, input: &str) -> Result<(), Box<dyn std::error::Error>> {
    let parts: Vec<&str> = input.splitn(2, ' ').collect();
    
    match parts[0] {
        "post" => {
            if parts.len() > 1 {
                self.publish_post(parts[1].to_string())?;
            } else {
                println!("Usage: post <message>");
            }
        }
        "list" => {
            self.list_posts();
        }
        "peers" => {
            let peer_count = self.swarm.connected_peers().count();
            println!("🤝 Connected peers: {}", peer_count);
            for peer in self.swarm.connected_peers() {
                println!("  - {}", peer);
            }
        }
        "quit" | "exit" => {
            println!("👋 Goodbye!");
            std::process::exit(0);
        }
        "help" => {
            println!("💬 Available commands:");
            println!("  post <message>  - Publish a post");
            println!("  list           - Show recent posts");
            println!("  peers          - Show connected peers");
            println!("  quit           - Exit");
        }
        "" => {
            // Empty input, do nothing
        }
        _ => {
            println!("❓ Unknown command: {}. Type 'help' for available commands.", parts[0]);
        }
    }
    
    Ok(())
}

async fn handle_swarm_event(
    &mut self,
    event: SwarmEvent<MyceliaBehaviourEvent>,
) -> Result<(), Box<dyn std::error::Error>> {
    match event {
        SwarmEvent::NewListenAddr { address, .. } => {
            println!("📡 Listening on {address}");
        }
        SwarmEvent::Behaviour(MyceliaBehaviourEvent::Gossipsub(GossipEvent::Message {
            message,
            ..
        })) => {
            if let Ok(post) = bincode::deserialize::<SimplePost>(&message.data) {
                // Don't show our own posts again
                if post.author != self.node_name {
                    self.handle_received_post(post);
                }
            }
        }
        SwarmEvent::Behaviour(MyceliaBehaviourEvent::Mdns(MdnsEvent::Discovered(peers))) => {
            for (peer_id, _) in peers {
                println!("🤝 Discovered peer: {peer_id}");
                self.swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer_id);
            }
        }
        SwarmEvent::Behaviour(MyceliaBehaviourEvent::Mdns(MdnsEvent::Expired(peers))) => {
            for (peer_id, _) in peers {
                println!("👋 Peer expired: {peer_id}");
                self.swarm.behaviour_mut().gossipsub.remove_explicit_peer(&peer_id);
            }
        }
        SwarmEvent::ConnectionEstablished { peer_id, .. } => {
            println!("🔗 Connected to peer: {peer_id}");
        }
        SwarmEvent::ConnectionClosed { peer_id, .. } => {
            println!("❌ Disconnected from peer: {peer_id}");
        }
        _ => {}
    }
    
    Ok(())
}
```

}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
env_logger::init();

```
let args = Args::parse();

let mut node = MyceliaNode::new(args.name).await?;
node.start_listening(args.port).await?;

if let Some(peer_addr) = args.peer {
    println!("🔌 Connecting to peer: {}", peer_addr);
    node.connect_to_peer(peer_addr).await?;
}

node.run().await
```

}
EOF

# Build the project

echo -e “${BLUE}🔨 Building the project…${NC}”
cargo build –release

# Create a demo script

echo -e “${BLUE}📝 Creating demo script…${NC}”
cd ..
cat > demo.sh << ‘EOF’
#!/bin/bash

# Mycelia Network Demo

echo “🍄 Mycelia Network Demo”
echo “This will start 3 nodes that can talk to each other”
echo “”

# Start first node (bootstrap)

echo “Starting bootstrap node on port 4001…”
RUST_LOG=info cargo run –bin mycelia-simple – –port 4001 –name “Bootstrap” &
BOOTSTRAP_PID=$!

sleep 2

# Start second node

echo “Starting second node on port 4002…”
RUST_LOG=info cargo run –bin mycelia-simple – –port 4002 –name “Alice” –peer /ip4/127.0.0.1/tcp/4001 &
ALICE_PID=$!

sleep 2

# Start third node

echo “Starting third node on port 4003…”
RUST_LOG=info cargo run –bin mycelia-simple – –port 4003 –name “Bob” –peer /ip4/127.0.0.1/tcp/4001 &
BOB_PID=$!

echo “”
echo “🌐 Network started!”
echo “📱 Open 3 terminals and connect to each node:”
echo “   Node 1 (Bootstrap): telnet localhost 4001”
echo “   Node 2 (Alice):     telnet localhost 4002”
echo “   Node 3 (Bob):       telnet localhost 4003”
echo “”
echo “💬 Try posting messages and see them propagate!”
echo “   Commands: post <message>, list, peers, quit”
echo “”
echo “Press Ctrl+C to stop all nodes…”

# Handle cleanup

trap “echo ‘’; echo ‘Stopping nodes…’; kill $BOOTSTRAP_PID $ALICE_PID $BOB_PID 2>/dev/null; exit” INT

wait
EOF

chmod +x demo.sh

# Create README

cat > README.md << ‘EOF’

# 🍄 Mycelia Network - Quick Start

You’ve successfully set up a minimal Mycelia Network node!

## What You Have

- A working P2P network node built with libp2p
- Peer discovery using mDNS (finds other nodes automatically)
- Content sharing via gossipsub protocol
- Simple command-line interface

## Running Your First Network

### Single Node

```bash
cargo run --bin mycelia-simple -- --name "YourName"
```

### Multi-Node Network

```bash
# Terminal 1 - Bootstrap node
cargo run --bin mycelia-simple -- --port 4001 --name "Bootstrap"

# Terminal 2 - Connect to bootstrap
cargo run --bin mycelia-simple -- --port 4002 --name "Alice" --peer /ip4/127.0.0.1/tcp/4001

# Terminal 3 - Another peer
cargo run --bin mycelia-simple -- --port 4003 --name "Bob" --peer /ip4/127.0.0.1/tcp/4001
```

### Or Use the Demo Script

```bash
./demo.sh
```

## Commands

Once your node is running, try these commands:

- `post Hello, Mycelia Network!` - Publish a message
- `list` - Show recent posts
- `peers` - Show connected peers
- `help` - Show all commands
- `quit` - Exit

## What’s Next?

This is just the beginning! From here you can:

1. **Add Math Integration**: Connect your dynamic-math platform for social algorithms
1. **Create Communities**: Build governance and moderation features
1. **Add Desktop UI**: Create the Tauri app for a better user experience
1. **Deploy to Cloud**: Set up bootstrap nodes for a real network
1. **Build Mobile Apps**: Create React Native or Flutter apps

## Features to Add

- User reputation systems
- Community governance
- Content moderation
- File sharing
- End-to-end encryption
- Mobile apps
- Web interface

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Node A    │◄──►│   Node B    │◄──►│   Node C    │
│  (Bootstrap)│    │   (Alice)   │    │    (Bob)    │
│             │    │             │    │             │
│ Port: 4001  │    │ Port: 4002  │    │ Port: 4003  │
└─────────────┘    └─────────────┘    └─────────────┘
       ▲                   ▲                   ▲
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    📡 P2P Network
                  (libp2p + gossipsub)
```

Happy building! 🚀
EOF

echo “”
echo -e “${GREEN}✅ Mycelia Network Quick Start is ready!${NC}”
echo “”
echo -e “${BLUE}🚀 To get started:${NC}”
echo -e “  1. cd $WORKSPACE”
echo -e “  2. cargo run –bin mycelia-simple – –name "YourName"”
echo -e “  3. Type ‘post Hello, Mycelia!’ to publish your first message”
echo “”
echo -e “${BLUE}🌐 For a multi-node demo:${NC}”
echo -e “  1. cd $WORKSPACE”
echo -e “  2. ./demo.sh”
echo “”
echo -e “${YELLOW}📚 Read README.md for more details${NC}”
echo “”
echo -e “${GREEN}🍄 Welcome to the Mycelia Network!${NC}”
echo -e “${GREEN}   ‘Of the people, by the people, and for the people!’${NC}”
EOF

chmod +x quick_start.sh

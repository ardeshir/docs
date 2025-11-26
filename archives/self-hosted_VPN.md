# Guide to self-hosted WireGuard using Algo VPP

The technology and setup for both macOS work machine and Windows PC.

## **Technology Overview**

### **WireGuard Protocol**

WireGuard is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography, designed to be faster, simpler, leaner, and more useful than IPsec while being considerably more performant than OpenVPN. WireGuard securely encapsulates IP packets over UDP using public-key cryptography for the initial handshake .

**Key Technical Advantages:**

- Designed with ease-of-implementation and simplicity in mind, meant to be easily implemented in very few lines of code and easily auditable for security vulnerabilities 
- Lives inside the Linux kernel, meaning secure networking can be very high-speed and suitable for both small embedded devices and fully loaded backbone routers 
- Uses modern cryptography: ChaCha20 for encryption, Poly1305 for authentication, and Curve25519 for key exchange

### **Algo VPN Technology**

Algo was introduced in 2016 by Trail of Bits as a self-hosted VPN server focused on security and ease of use, relying on modern protocols and cipher suites . Algo generates .conf files and QR codes for iOS, macOS, Android, and Windows WireGuard clients and includes helper scripts to add, remove, and manage users .

**Security Design:**

- Does not support legacy cipher suites or protocols like L2TP, IKEv1, or RSA and does not install Tor, OpenVPN, or other risky servers 
- Minimal attack surface with only essential components
- Automated deployment and configuration

## **Prerequisites and Server Setup**

### **1. Choose a Cloud Provider**

Algo supports DigitalOcean (most user friendly), Amazon Lightsail, Amazon EC2, Vultr, Microsoft Azure, Google Compute Engine, Scaleway, OpenStack, CloudStack, Hetzner Cloud, Linode, or your own Ubuntu server .

**Recommended: DigitalOcean** (most beginner-friendly)

- Create account at [digitalocean.com](http://digitalocean.com)
- Generate API token in Account → API → Personal Access Tokens
- Choose a server location (ideally close to your location for speed)

### **2. Install Algo VPN**

**On macOS (your work machine):**

```bash
# Install required dependencies
brew install python3 ansible

# Clone Algo repository
git clone https://github.com/trailofbits/algo.git
cd algo

# Install Python requirements
python3 -m pip install -U -r requirements.txt
```

**On Windows (use WSL2 or Git Bash):**

```bash
# If using WSL2 Ubuntu
sudo apt update
sudo apt install python3-pip python3-virtualenv

# Clone and setup
git clone https://github.com/trailofbits/algo.git
cd algo
python3 -m pip install -U -r requirements.txt
```

### **3. Configure Algo**

Edit the `config.cfg` file:

```ini
# List of users for WireGuard
users:
  - macbook_work
  - windows_personal
  - phone
  - tablet

# Server configuration
server_name: "my-vpn-server"
ondemand_cellular: false
ondemand_wifi: false
local_service_ip: "{{ ansible_default_ipv4['address'] }}"
```

### **4. Deploy the Server**

Run the deployment command:

```bash
./algo
```

**Follow the interactive prompts:**

1. Choose cloud provider (e.g., DigitalOcean)
1. Enter your API token
1. Select server region
1. Confirm user list
1. Choose additional features (DNS blocking, etc.)

All the files (certificates, configs) required to configure your desktop and mobile VPN clients using WireGuard will be placed under the algo\configs<PUBLIC_IP_ADDRESS_OF_DROPLET>\wireguard\ folder .

## **Client Setup: macOS (Work Machine)**

### **1. Install WireGuard**

On macOS, install the WireGuard app from the Mac App Store. WireGuard will appear in the menu bar once you run the app .

### **2. Import Configuration**

Click on the WireGuard icon, choose Import tunnel(s) from file…, then select the appropriate WireGuard configuration file .

**Manual import via terminal:**

```bash
# Download config from your server
scp root@YOUR_SERVER_IP:/root/algo/configs/YOUR_SERVER_IP/wireguard/macbook_work.conf ~/Downloads/

# Or copy directly if you have the file locally
cp algo/configs/YOUR_SERVER_IP/wireguard/macbook_work.conf ~/Downloads/
```

### **3. Configure Connection**

1. Open WireGuard app from menu bar
1. Click “Import tunnel(s) from file…”
1. Select `macbook_work.conf`
1. Click “Activate” to connect

**Advanced macOS Configuration:**
You can enable “Connect on Demand” and/or exclude certain trusted Wi-Fi networks (such as your home or work) by editing the tunnel configuration in the WireGuard app .

Example configuration for Connect on Demand:

1. Edit tunnel in WireGuard app
1. Add “On Demand” rules:

- Connect on cellular networks
- Connect on untrusted Wi-Fi
- Disconnect on trusted networks (home/office)

## **Client Setup: Windows (Personal PC)**

### **1. Install WireGuard**

Install the WireGuard VPN Client from their website, import the generated wireguard/<username>.conf file to your device, then set up a new connection with it .

**Download from:** <https://www.wireguard.com/install/>

### **2. Import Configuration**

1. Open WireGuard application
1. Click “Add Tunnel” → “Add from file”
1. Select `windows_personal.conf` from your Algo configs folder
1. Click “Activate” to connect

**Alternative - Manual Configuration:**
If you need to manually enter configuration:

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.19.49.X/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = YOUR_SERVER_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
```

### **3. Windows-Specific Optimizations**

**Set up as Windows Service (optional):**

```powershell
# Run PowerShell as Administrator
# Install as service for automatic startup
wireguard /installtunnelservice "path\to\windows_personal.conf"
```

**Firewall Configuration:**

1. Open Windows Defender Firewall
1. Allow WireGuard through firewall
1. Create inbound rule for UDP port 51820

## **Server Configuration and Firewall Setup**

### **Firewall Configuration on Server**

You may need multiple ports to be accessible for WireGuard - allow inbound WireGuard traffic on UDP Port 51820 and limit inbound SSH traffic to certain IP addresses .

**DigitalOcean Firewall Setup:**
Head over to Networking → Firewalls and Create Firewall. Allow inbound WireGuard traffic on UDP Port 51820 .

**Server-side UFW configuration:**

```bash
# SSH to your server
ssh root@YOUR_SERVER_IP

# Configure UFW firewall
ufw allow 22/tcp    # SSH
ufw allow 51820/udp # WireGuard
ufw enable
```

## **Advanced Configuration Options**

### **Split Tunneling Setup**

Configure specific applications or traffic to bypass VPN:

**macOS:**

```bash
# Route specific networks through VPN only
# Edit WireGuard config to change AllowedIPs
AllowedIPs = 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
```

**Windows:**
Use WireGuard’s “Allowed IPs” field to specify which traffic routes through VPN.

### **DNS Configuration**

**Custom DNS servers in WireGuard config:**

```ini
[Interface]
DNS = 1.1.1.1, 1.0.0.1  # Cloudflare
# Or use
DNS = 9.9.9.9, 149.112.112.112  # Quad9
# Or use your server's DNS for ad blocking
DNS = YOUR_SERVER_IP
```

### **Kill Switch Configuration**

**macOS:**
Built into WireGuard app - blocks all traffic when VPN disconnects.

**Windows:**

1. Open WireGuard app
1. Edit tunnel configuration
1. Enable “Block untunneled traffic (kill-switch)”

## **Security Best Practices**

### **1. Server Hardening**

```bash
# SSH to server and implement security measures
ssh root@YOUR_SERVER_IP

# Disable password authentication
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Set up automatic security updates
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

### **2. Regular Key Rotation**

```bash
# Generate new client configuration
cd algo
./algo update-users
```

### **3. Monitoring and Logging**

```bash
# Check WireGuard status on server
wg show

# Monitor connections
journalctl -u wg-quick@wg0 -f
```

## **Troubleshooting Common Issues**

### **Connection Problems**

1. **Can’t connect:** Verify firewall settings on server and client
1. **Slow speeds:** Try different server regions, check local network
1. **DNS leaks:** Verify DNS configuration in WireGuard settings

### **macOS Specific**

- **Permission issues:** Grant Full Disk Access to WireGuard in System Preferences
- **Network conflicts:** Disable other VPN software

### **Windows Specific**

- **Service issues:** Run as Administrator
- **Driver problems:** Reinstall WireGuard application

## **Performance Optimization**

### **Server Optimization**

```bash
# Optimize server for WireGuard performance
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p
```

### **Client Optimization**

- Use fastest WireGuard protocol
- Choose geographically closest server
- Configure split tunneling for local traffic

This setup gives you complete control over your VPN infrastructure with enterprise-grade security and privacy, eliminating dependence on third-party VPN providers while maintaining professional-grade encryption and performance.
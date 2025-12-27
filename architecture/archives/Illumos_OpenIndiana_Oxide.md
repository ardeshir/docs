# Illumos: OpenIndiana instance running on your Oxide Rack

While all modern Illumos distributions share a common ancestor in `illumos-gate` (which was forked from OpenSolaris `snv_134`), they have diverged over the last 15+ years based on different philosophies and goals.

Alas, no distribution is a 1:1 match for OpenSolaris 2009.06, but one stands out for intentionally preserving the administrative "feel" and compatibility of that era:

*   **For the most direct lineage and a general-purpose successor:** **OpenIndiana** is the closest in terms of project goals and community continuation.
*   **For the closest administrative *feel* and philosophical purity to classic Sun Solaris/OpenSolaris:** **Tribblix** is arguably the winner, although it is a smaller project.


### A Detailed Analysis

Deep dive into the most relevant Illumos distributions, judged by your criteria of IPS and SMF compatibility and the overall "feel" of the OpenSolaris core system.

---

### 1. OpenIndiana: The Direct Successor

OpenIndiana was created immediately after Oracle discontinued OpenSolaris. Its explicit goal was to "continue the development and distribution of the OpenSolaris operating system."

*   **Philosophy:** To be a complete, general-purpose desktop and server operating system, just as OpenSolaris was intended to be. It is the most direct continuation of the `osol` consolidation.
*   **Core System, IPS, and SMF:**
    *   **SMF (Service Management Facility):** Works exactly as you remember. The `svcs`, `svcadm`, and `svccfg` commands are the standard for service management. Manifests are created and imported in the same way. This is a core Illumos technology that has been enhanced but not fundamentally changed.
    *   **IPS (Image Packaging System):** IPS is the native package manager. The OpenIndiana "Hipster" branch has a large, actively maintained repository that is a direct evolution of the original OpenSolaris package set. You will find that `pkg install`, `pkg update`, and managing publishers feels very familiar.
*   **Where it has Diverged:**
    *   **Modernization:** OpenIndiana has actively modernized the system. It uses modern GCC compilers, has updated drivers, and ships with modern desktop environments like MATE. While this is a good thing for usability, it means the userland and available software are very different from 2009.
    *   **Installer:** It uses a modern graphical installer, which is easier to use but different from the classic text-based or CDE-based installers of Solaris 10.

**Conclusion:** If you want the distribution that picked up the torch directly from the OpenSolaris project and has the largest community and package repository, **OpenIndiana is your choice**. The core system administration (SMF, ZFS, DTrace) will be immediately familiar.

---

### 2. Tribblix: The Purist's Choice

Tribblix is a lesser-known but fascinating distribution created and maintained by Peter Tribble, a former Sun Microsystems engineer. Its philosophy is explicitly about preserving the traditional Solaris/OpenSolaris experience.

*   **Philosophy:** "Retro-computing with a modern twist." It aims to provide a system that *feels* and *works* like Solaris 2.x, Solaris 10, or OpenSolaris, but built on a modern Illumos kernel.
*   **Core System, IPS, and SMF:**
    *   **SMF/IPS:** Both are core to the system and used in the standard, expected way. The experience is pure Illumos.
    *   **Installation & Administration:** This is where Tribblix shines for your use case. It uses a **text-based installer** that is deliberately modeled on the classic Solaris installer. The layout of `/etc`, the default shell, and many administrative choices are made to align with historical Solaris practices.
    *   **Compatibility:** Tribblix makes a concerted effort to maintain compatibility with older Solaris software. It includes legacy libraries and tools that other distributions may have deprecated.
*   **Where it has Diverged:**
    *   While the *feel* is classic, the underlying kernel and core utilities are fully modern, pulling directly from `illumos-gate`. You get modern ZFS, DTrace, and security fixes.
    *   It's a much smaller project, primarily driven by a single developer. The package repository is smaller than OpenIndiana's, though it is well-curated.

**Conclusion:** If your primary goal is to have an environment where the administrative commands, file system layout, and overall *spirit* are as close as possible to what you remember from OpenSolaris, **Tribblix is the strongest candidate**. It is the most philosophically aligned with the Sun era.

---

### 3. OmniOS: The Lean Server

OmniOS was created by engineers at OmniTI for their specific server needs. It has a different philosophy from the others.

*   **Philosophy:** A no-nonsense, minimalist, server-only operating system. It values stability, predictability, and a small footprint above all else.
*   **Core System, IPS, and SMF:**
    *   SMF and IPS are fundamental here as well. The tooling is the same.
*   **Where it has Diverged (Significantly):**
    *   **Minimalism:** An OmniOS base install is *extremely* minimal. Many components that were standard in OpenSolaris (like a GUI, many desktop libraries, etc.) are not included and may not even be in the repository. This is a major departure from the "batteries-included" feel of OpenSolaris.
    *   **Installer:** It uses its own `kayak` text-based installer, which is powerful but different from the classic Solaris installer.
    *   **Package Set:** The IPS repository is curated for server workloads. You will not find the breadth of packages that OpenIndiana offers. The focus is on stability, with LTS (Long-Term Support) releases.

**Conclusion:** While OmniOS is an excellent, robust server OS, it has **diverged the most** from the general-purpose nature of OpenSolaris. It is not the closest match for your requirements.

---

### Comparison Table

| Feature                         | OpenIndiana                                     | Tribblix                                                       | OmniOS                                              |
| ------------------------------- | ----------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------- |
| **Philosophy**                  | Direct successor to OpenSolaris (General Purpose) | Preserve the classic Solaris look and feel (Retro-Modern)      | Minimalist, stable, server-only OS                  |
| **Installer**                   | Modern Graphical/Text                           | Classic Solaris-style Text Installer                           | `kayak` Text Installer                              |
| **Core Admin (IPS/SMF)**        | **Feels Identical**                             | **Feels Identical**                                            | **Feels Identical**                                 |
| **Default Package Set**         | Large, "batteries-included" with modern DE      | Small, classic feel, with optional X11/FVWM                    | Extremely minimal, server-focused                   |
| **"Feel" vs. OpenSolaris 2009** | Modernized, but direct lineage is clear         | **Closest administrative feel and philosophy**                 | Diverged significantly towards minimalism           |
| **Target Use Case**             | Desktop, Workstation, General-Purpose Server    | Hobbyists, Solaris veterans, specific server workloads         | Production Servers, Virtualization Hosts            |

### Final Verdict and Recommendation

Based on your specific request for a system where "IPS and SMF will just work like the OpenSolaris before the fork," both OpenIndiana and Tribblix fit the bill for the core tooling. However, the nuance lies in the overall experience.

1.  **Choose OpenIndiana if:**
    *   You want the most straightforward continuation of the OpenSolaris project.
    *   You need a large, modern package repository.
    *   You value a larger community and more frequent updates (via the Hipster branch).
    *   You are comfortable with a modernized userland sitting on top of the familiar core.

2.  **Choose Tribblix if:**
    *   Your highest priority is the **administrative feel and philosophical purity** of the classic Sun Microsystems era.
    *   You appreciate a system designed by a Solaris veteran with an eye for historical consistency.
    *   You are comfortable with a smaller package set and community.
    *   The idea of a classic installer and system layout appeals to you.

For your specific quest for the "closest compatibility with its roots," **I would recommend you start by trying Tribblix.** It sounds like it was made for users exactly like you. You can then evaluate OpenIndiana to see if its modernizations and larger package set are more beneficial for your ultimate goals.

### Resources and Links

*   **Illumos Official Site:** [https://illumos.org/](https://illumos.org/)
*   **illumos-gate Source Code:** [https://github.com/illumos/illumos-gate](https://github.com/illumos/illumos-gate)
*   **OpenIndiana:**
    *   Homepage: [https://www.openindiana.org/](https://www.openindiana.org/)
    *   Documentation: [https://www.openindiana.org/documentation/](https://www.openindiana.org/documentation/)
*   **Tribblix:**
    *   Homepage: [https://tribblix.org/](https://tribblix.org/)
    *   Peter Tribble's Blog (essential reading for the philosophy): [https://blog.tribblix.org/](https://blog.tribblix.org/)
*   **OmniOS:**
    *   Homepage: [https://omnios.org/](https://omnios.org/)
    *   Documentation: [https://omnios.org/documentation/](https://omnios.org/documentation/)
*   **SMF & IPS Documentation:**
    *   Oracle Solaris 11 (Very similar to Illumos): [Service Management Facility (SMF)](https://docs.oracle.com/cd/E53394_01/html/E54784/index.html)
    *   Oracle Solaris 11: [Image Packaging System (IPS)](https://docs.oracle.com/cd/E53394_01/html/E54746/index.html)

## Step-by Step Install 
Based on my research, here are the exact steps to get an OpenIndiana instance running on  Oxide rack:

## Prerequisites
- Access to your Oxide rack's management interface/CLI
- The Oxide CLI tool installed and configured
- OpenIndiana installation ISO or image file

## Step-by-Step Process

### 1. **Prepare the OpenIndiana Image**
First, you'll need to obtain and prepare an OpenIndiana image:
- Download the latest OpenIndiana ISO from the official website
- Convert it to a format suitable for Oxide (typically a raw disk image or qcow2)

### 2. **Upload the Image to Oxide**
Using the Oxide CLI:
```bash
# Upload the OpenIndiana image to your project
oxide image create \
  --name "openindiana-latest" \
  --description "OpenIndiana illumos distribution" \
  --file /path/to/openindiana.iso \
  --project your-project-name
```

### 3. **Create a Disk from the Image**
```bash
# Create a disk from the uploaded image
oxide disk create \
  --name "openindiana-boot-disk" \
  --size 32GiB \
  --image openindiana-latest \
  --project your-project-name
```

### 4. **Create the Instance**
```bash
# Create the OpenIndiana instance
oxide instance create \
  --name "openindiana-vm" \
  --image openindiana-latest \
  --cpu-count 4 \
  --memory 8GiB \
  --boot-disk openindiana-boot-disk \
  --project your-project-name
```

### 5. **Configure Networking**
```bash
# Create a VPC if you don't have one
oxide vpc create --name "main-vpc" --project your-project-name

# Create a subnet
oxide vpc-subnet create \
  --name "main-subnet" \
  --vpc main-vpc \
  --ipv4-block "10.0.0.0/24" \
  --project your-project-name

# Attach network interface to instance
oxide instance-network-interface create \
  --instance openindiana-vm \
  --name "primary-nic" \
  --subnet main-subnet \
  --project your-project-name
```

### 6. **Start the Instance**
```bash
# Start your OpenIndiana instance
oxide instance start --name openindiana-vm --project your-project-name
```

### 7. **Access the Instance**
```bash
# Get instance details including IP address
oxide instance view --name openindiana-vm --project your-project-name

# Connect via serial console for initial setup
oxide instance serial-console --name openindiana-vm --project your-project-name
```

## Important Considerations

**illumos Compatibility**: Helios, a distribution powering the Oxide Computer Rack, shows that illumos distributions work well on Oxide hardware. However, you'll need to ensure OpenIndiana has the necessary virtio drivers for optimal performance.

**Boot Process**: You may need to boot from the ISO first to perform installation, then create a separate boot disk from the installed system.

**Networking**: The Oxide rack uses Geneve which provides UDP encapsulation with custom headers for VPC networking, which should be compatible with OpenIndiana's networking stack.

## Alternative Approach
If direct ISO boot doesn't work, you might need to:
1. Create a minimal Linux VM first
2. Use that to create a proper OpenIndiana disk image
3. Import that image as a custom image in Oxide

This process leverages Oxide's cloud-like instance management while getting you the OpenSolaris-compatible OpenIndiana system. 

## Additional Info: 

A custom, non-standard OS running on a sophisticated hyperconverged platform like Oxide requires a clear, methodical process.

Oxide racks are designed for operational excellence and use a custom hypervisor (`protox`, based on `bhyve`) and control plane. While they don't offer a pre-built OpenIndiana image, the underlying technology is perfectly capable of running it. The process involves preparing a custom image locally and then uploading it to the Oxide control plane.


### High-Level Overview

The strategy is to prepare a bootable, pre-installed disk image of OpenIndiana on a local machine. This image will have its ZFS root pool expanded and a user account with an SSH key pre-configured. We will then upload this prepared image to Oxide and launch an instance from it.

**Phases:**
1.  **Image Preparation:** Download, convert, resize, and pre-configure the OpenIndiana image locally.
2.  **Oxide Deployment:** Upload the prepared image to the Oxide control plane and create an instance.
3.  **Post-Boot Configuration:** Perform initial network configuration inside the running instance.

---

### Prerequisites

*   **Local Machine:** A Linux or macOS machine with QEMU, `zstd`, and `xz` utilities installed.
    *   On Debian/Ubuntu: `sudo apt-get install qemu-system-x86 xz-utils zstd`
    *   On macOS (with Homebrew): `brew install qemu zstd`
*   **Oxide Access:**
    *   You have credentials for your Oxide Rack's control plane.
    *   You have the Oxide command-line interface, `omicron`, installed and configured.
    *   You know the name of the project within which you will create the image and instance.

---

### Phase 1: Image Preparation (On Your Local Machine)

This is the most critical phase. We will take a generic OpenIndiana image and customize it for use on Oxide.

#### Step 1: Download the OpenIndiana USB Image

We will use the "Hipster" USB image. It is essentially a raw disk image, which is the perfect starting point.

1.  Navigate to the OpenIndiana Hipster downloads page: [https://www.openindiana.org/download/](https://www.openindiana.org/download/)
2.  Find the latest **USB Image**. It will be a file ending in `.usb.xz`.
3.  Download it using your browser or `wget`:

    ```bash
    # Example for a specific version, replace with the latest
    wget https://dl.openindiana.org/isos/hipster/2023.04/OI-hipster-2023.04.usb.xz
    ```

#### Step 2: Decompress the Image

The downloaded file is compressed with `xz`. Decompress it to get the raw image file (`.img`).

```bash
unxz OI-hipster-2023.04.usb.xz
# This will produce a file named OI-hipster-2023.04.usb
# Let's rename it for simplicity
mv OI-hipster-2023.04.usb openindiana.img
```

#### Step 3: Resize the Image

The default USB image is small (around 4 GB). You'll want a larger root disk for your instance. Let's resize it to 50 GB.

```bash
# qemu-img is a safe and reliable tool for this
qemu-img resize openindiana.img 50G
```
This expands the image file, but the ZFS filesystem inside it is still the original size. We'll fix that in the next step.

#### Step 4: Customize the Image using a Local VM

The safest way to modify the ZFS pool and configure the OS is to boot the image in a local QEMU virtual machine.

1.  **Boot the image with QEMU:**

    ```bash
    qemu-system-x86_64 -m 4G -drive file=openindiana.img,format=raw
    ```

2.  **Log in to the VM:** The OpenIndiana live image will boot to a graphical desktop. Open a terminal. The default user is `jack` with the password `openindiana`. Gain root privileges:
    ```bash
    su -
    # Password: openindiana
    ```
    Alternatively, you can boot to the console by selecting the "Text Installer and Emergency Console" option in the GRUB boot menu. Default login is `root`, password `openindiana`.

3.  **Expand the ZFS Pool:** Now, we'll tell ZFS to use the extra space we added to the disk image.
    *   First, find the device name for the ZFS pool. It's usually the first disk.

        ```bash
        # List the pools
        zpool list
        # NAME    SIZE  ALLOC   FREE  CAP  DEDUP  HEALTH  ALTROOT
        # rpool  3.81G  2.34G  1.47G  61%  1.00x  ONLINE  -

        # Check the status to find the device
        zpool status rpool
        # The device will likely be cXtYdZ where X, Y, Z are numbers.
        # It corresponds to the virtual disk.
        ```
    *   Now, tell the specific disk device in the pool to auto-expand. Let's assume the device is `c1t0d0`.

        ```bash
        # Put the disk online and trigger auto-expansion
        zpool online -e rpool c1t0d0

        # Verify the new size
        zpool list rpool
        # NAME   SIZE  ALLOC   FREE  CAP  DEDUP  HEALTH  ALTROOT
        # rpool  49.8G  2.34G  47.4G   4%  1.00x  ONLINE  -
        ```
    *   The pool is now expanded, but the root filesystem dataset might have a quota. Let's remove it.
        ```bash
        zfs set quota=none rpool/ROOT/openindiana
        ```

4.  **Create a User and Add Your SSH Key:** For security, we will create a dedicated user for SSH access and disable root login.
    *   Create a user (e.g., `admin`). The `-m` flag creates a home directory.

        ```bash
        useradd -m -s /usr/bin/bash admin
        passwd admin
        # Set a strong temporary password. You will use SSH keys primarily.
        ```
    *   Create the `.ssh` directory and `authorized_keys` file for your new user.

        ```bash
        mkdir -p /export/home/admin/.ssh
        chmod 700 /export/home/admin/.ssh

        # Use an editor like 'vi' or 'nano' to add your public SSH key
        # Or, use a heredoc from the root shell
        cat <<EOF > /export/home/admin/.ssh/authorized_keys
        ssh-rsa AAAA... your public key ... user@host
        EOF

        chmod 600 /export/home/admin/.ssh/authorized_keys
        chown -R admin:staff /export/home/admin/.ssh
        ```

5.  **Harden SSH and Clean Up:**
    *   Disable password and root login via SSH for better security.

        ```bash
        # Edit the SSH config
        vi /etc/ssh/sshd_config
        # Ensure these lines are present and not commented out:
        PermitRootLogin no
        PasswordAuthentication no
        PubkeyAuthentication yes

        # Refresh the SSH service to apply changes
        svcadm restart ssh
        ```
    *   (Optional) Clean up temporary files, bash history, etc.
        ```bash
        history -c
        rm /root/.bash_history
        ```

6.  **Shut Down the VM:**
    ```bash
    # In the VM's root shell
    shutdown -y -g0 -i0
    ```
    Wait for the QEMU process to exit. Your `openindiana.img` file is now fully prepared.

#### Step 5: Compress the Final Image for Upload

Oxide's control plane can handle compressed images, which makes uploading much faster. We'll use `zstd` for its excellent speed and compression ratio.

```bash
zstd -T0 -v openindiana.img -o openindiana.img.zst
```
*   `-T0`: Use all available CPU cores for compression.
*   `-v`: Verbose output.

You now have a file named `openindiana.img.zst` ready for Oxide.

---

### Phase 2: Uploading and Deploying on Oxide

Now we use the `omicron` CLI to get our image into the Oxide Rack.

#### Step 6: Upload the Image to Oxide

Use the `omicron image create` command.

```bash
omicron image create \
  --name "openindiana-hipster-2023.04-custom" \
  --os illumos \
  --version "2023.04" \
  --description "Custom OpenIndiana Hipster image, pre-configured" \
  --file openindiana.img.zst
```
*   `--os illumos`: This is the most appropriate OS type available in Oxide's enumeration.
*   This command will show a progress bar as the image is uploaded. It may take some time depending on your connection speed.

#### Step 7: Create the Instance

Once the image is available, create an instance from it.

1.  Find your image ID: `omicron image list`
2.  List available instance shapes: `omicron shape list`
3.  Create the instance. You'll need to know which network to attach it to (`omicron network list`).

    ```bash
    # Example using a shape
    omicron instance create \
      --name "oi-dev-01" \
      --image "openindiana-hipster-2023.04-custom" \
      --shape "c2.medium" \
      --network <your-network-name-or-id>
    ```

The instance will be provisioned. You can check its status with `omicron instance list`.

---

### Phase 3: First Boot and Network Configuration

Your instance is running, but it doesn't have network connectivity yet because it couldn't automatically configure it. We'll do this manually via the serial console.

#### Step 8: Connect to the Instance Console

Get the web-based serial console URL for your new instance.

```bash
omicron instance get-console-url oi-dev-01
# This will output a URL. Open it in your browser.
```

#### Step 9: Configure Networking

In the console, you will see the OpenIndiana boot sequence and a login prompt.

1.  **Log in:** Use the `admin` user and the password you set in the QEMU VM.
2.  **Gain root privileges:** `su -` (enter the root password you set, likely `openindiana`).
3.  **Identify the Network Interface:** Oxide instances have a virtual network interface. Find its name.
    ```bash
    dladm show-phys
    # LINK         MEDIA                STATE      SPEED  DUPLEX    DEVICE
    # net0         Ethernet             up         10000  full      vioif0
    ```
    The link name is `net0`.

4.  **Configure a Static IP:** Get the IP address, subnet mask, and gateway assigned to your instance from the Oxide UI or via `omicron instance get oi-dev-01`.
    *   Let's assume the instance IP is `10.0.1.50`, the prefix is `/24`, and the gateway is `10.0.1.1`.

    ```bash
    # Create the network interface plumbing
    ipadm create-if net0

    # Assign the static IP address
    ipadm create-addr -T static -a 10.0.1.50/24 net0/v4static

    # Add the default route (the -p makes it persistent)
    route -p add default 10.0.1.1
    ```

5.  **Configure DNS:**
    *   Set the DNS servers.
        ```bash
        svccfg -s dns/client setprop 'config/nameserver' = net_address: '(8.8.8.8 1.1.1.1)'
        svccfg -s dns/client setprop 'config/search' = astring: '("your.internal.domain")'
        ```
    *   Update the name service switch to use DNS.
        ```bash
        # Ensure /etc/nsswitch.conf has 'dns' for hosts
        # The line should look like:
        # hosts:      files dns
        cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
        cp /etc/nsswitch.dns /etc/nsswitch.conf
        ```
    *   Refresh the services.
        ```bash
        svcadm refresh dns/client
        svcadm refresh name-service/cache
        ```

6.  **Verify Connectivity:**
    ```bash
    ping 8.8.8.8
    ping openindiana.org
    pkg refresh
    ```
    If these commands work, your instance is online!

---

### Phase 4: Final Verification

You can now exit the console and access your instance directly via SSH using the key you configured.

```bash
ssh admin@10.0.1.50
```

Congratulations! You have a fully functional OpenIndiana instance running on your Oxide Rack.

### Resources

*   **Oxide Command Line Guide:** [https://docs.oxide.computer/guides/omicron](https://docs.oxide.computer/guides/omicron)
*   **OpenIndiana Handbook:** [https://docs.openindiana.org/handbook/](https://docs.openindiana.org/handbook/)
*   **Illumos Networking (`dladm`, `ipadm`):** [Oracle Solaris 11.4 Docs - Administering TCP/IP Networks](https://docs.oracle.com/cd/E37838_01/html/E61022/index.html) (The commands are identical).

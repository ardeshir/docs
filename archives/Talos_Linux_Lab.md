# Oxide Rack with Talos linux

Talos Linux cluster (3 control plane, 3 worker nodes) running, on an Oxide rack, a setup proxy:

The primary tool for interacting with Talos Linux itself is `talosctl`. For interacting with the Kubernetes cluster running *on* Talos, you'll use `kubectl`.

**Assumptions:**
1.  Your Talos Linux cluster is already provisioned and running.
2.  You have network access to a "setup proxy" (e.g., a SOCKS5 or HTTP proxy) that can, in turn, reach the Talos control plane nodes on their API port (default: 50000 for Talos API, 6443 for Kubernetes API).
3.  You have the necessary `talosconfig` file for your cluster. This file contains endpoint information and client certificates required to authenticate with the Talos API. It's typically generated during the cluster bootstrap process (e.g., using `talosctl gen config` and then retrieved after `talosctl apply-config`).
4.  The IP addresses/hostnames of your three control plane nodes are known (e.g., `10.0.0.10`, `10.0.0.11`, `10.0.0.12`).

---

**Step 1: Install `talosctl` and `kubectl`**

If you don't have them already, install these CLI tools on the machine you'll be using to interact with the cluster (this machine must have access to the proxy).

*   **`talosctl`:**
    ```bash
    curl -sL https://talos.dev/install | sh
    # Or download from releases: https://github.com/siderolabs/talos/releases
    ```
*   **`kubectl`:**
    Follow the official Kubernetes installation guide: [https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

Verify installations:
```bash
talosctl version
kubectl version --client
```

---

**Step 2: Obtain `talosconfig`**

This is the crucial configuration file for `talosctl`.
*   If you used `talosctl gen config` during setup, you would have specified where to output it.
*   If Sidero (common with Oxide) or another tool provisioned Talos, there would be a method to retrieve this. For Sidero, you might get it from the Sidero API or UI.
*   Typically, it's named `talosconfig` or `~/.talos/config`.

Let's assume you have it saved as `./talosconfig` in your current directory for the examples below.

**Contents of a sample `talosconfig` (simplified):**
```yaml
context: my-talos-cluster
contexts:
  my-talos-cluster:
    ca: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
    crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
    key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t...
    # Endpoints might be pre-filled here, or you'll specify them with --nodes
    # endpoints:
    #   - 10.0.0.10
    #   - 10.0.0.11
    #   - 10.0.0.12
```

---

**Step 3: Configure Proxy for `talosctl`**

`talosctl` needs to be told to use your setup proxy to reach the Talos control plane nodes. The Talos API communicates over gRPC on port 50000 by default.

Let's say your proxy is a SOCKS5 proxy running at `proxy.example.com:1080`.

You can use the `--proxy` flag with `talosctl`:
```bash
# Example:
# talosctl --proxy socks5://proxy.example.com:1080 --nodes <CP1_IP>,<CP2_IP>,<CP3_IP> --talosconfig ./talosconfig <command>
```
Replace `<CP1_IP>`, `<CP2_IP>`, `<CP3_IP>` with the actual IPs of your control plane nodes.

For convenience, you can set environment variables for `talosctl`:
```bash
export TALOSCONFIG_PROXY=socks5://proxy.example.com:1080
# Or for general SOCKS proxy for many tools (talosctl might pick this up too)
export ALL_PROXY=socks5://proxy.example.com:1080
```
If `TALOSCONFIG_PROXY` is set, you might not need the `--proxy` flag explicitly.

---

**Step 4: Basic `talosctl` Commands**

You generally need to specify the control plane node endpoints for `talosctl` commands using the `--nodes` (or `-n`) flag, especially if they are not defined in your `talosconfig`. `talosctl` will try them in order until one responds.

Let the control plane IPs be `10.0.0.10`, `10.0.0.11`, `10.0.0.12`.
Let the proxy be `socks5://proxy.example.com:1080`.

1.  **Check Talos Version on Nodes:**
    ```bash
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.10,10.0.0.11,10.0.0.12 \
             --talosconfig ./talosconfig \
             version
    ```
    This command connects to *one* of the specified nodes through the proxy and reports its Talos version.

2.  **Get Health Status:**
    ```bash
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.10,10.0.0.11,10.0.0.12 \
             --talosconfig ./talosconfig \
             health
    ```

3.  **List Cluster Members (etcd status):**
    ```bash
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.10,10.0.0.11,10.0.0.12 \
             --talosconfig ./talosconfig \
             get members
    ```

4.  **List Nodes from Talos's perspective:**
    ```bash
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.10,10.0.0.11,10.0.0.12 \
             --talosconfig ./talosconfig \
             get nodes
    ```
    This shows all nodes (control plane and workers) recognized by the Talos control plane.

5.  **Read Kernel Logs (dmesg) from a specific node:**
    You need to target a single node for this. Let's pick `10.0.0.10`.
    ```bash
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.10 \
             --talosconfig ./talosconfig \
             dmesg -f # -f to follow
    ```

6.  **View Logs for a Specific Service on a Node:**
    For example, to see `kubelet` logs on worker node `10.0.0.20` (assuming this is a worker IP):
    ```bash
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.20 \
             --talosconfig ./talosconfig \
             logs kubelet
    ```
    Or on a control plane node for `etcd`:
    ```bash
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.10 \
             --talosconfig ./talosconfig \
             logs etcd
    ```

7.  **Upgrade Talos (Example - Read Docs First!):**
    This is a more advanced operation, ensure you understand the upgrade process from Talos documentation.
    ```bash
    # Example for upgrading a control plane node
    talosctl --proxy socks5://proxy.example.com:1080 \
             --nodes 10.0.0.10 \
             --talosconfig ./talosconfig \
             upgrade --image ghcr.io/siderolabs/installer:vX.Y.Z --preserve=true
    ```

---

**Step 5: Getting `kubeconfig` for `kubectl`**

Once `talosctl` can connect, you can retrieve the `kubeconfig` file needed by `kubectl`.
```bash
talosctl --proxy socks5://proxy.example.com:1080 \
         --nodes 10.0.0.10,10.0.0.11,10.0.0.12 \
         --talosconfig ./talosconfig \
         kubeconfig --force \
         ./kubeconfig-talos-oxide # Output to this file
```
The `--force` flag overwrites the destination file if it exists.
The generated `kubeconfig` will have the Kubernetes API server endpoint pointing to the control plane nodes (e.g., `https://10.0.0.10:6443`).

---

**Step 6: Configure Proxy for `kubectl`**

If your Kubernetes API server (running on the Talos control plane nodes, port 6443) is *also* only accessible via the proxy, `kubectl` needs to be configured to use it.

`kubectl` respects the `HTTPS_PROXY` environment variable.
```bash
export HTTPS_PROXY=http://proxy.example.com:1080 # If it's an HTTP proxy
# OR if your SOCKS5 proxy can also handle HTTPS:
export HTTPS_PROXY=socks5://proxy.example.com:1080
```
**Note:** The scheme for `HTTPS_PROXY` depends on what your proxy server supports for HTTPS traffic. Many SOCKS5 proxies can tunnel any TCP traffic, including HTTPS. If it's a dedicated HTTP/HTTPS proxy, use `http://`.

Set the `KUBECONFIG` environment variable:
```bash
export KUBECONFIG=./kubeconfig-talos-oxide
```

---

**Step 7: Basic `kubectl` Commands**

Now you can use `kubectl` to interact with your Kubernetes cluster.

1.  **Get Kubernetes Nodes:**
    ```bash
    kubectl get nodes -o wide
    ```
    You should see all 3 control plane and 3 worker nodes.

2.  **Get Pods in All Namespaces:**
    ```bash
    kubectl get pods -A
    ```

3.  **Check CoreDNS Pods:**
    ```bash
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    ```

4.  **View Logs of a Pod:**
    First, find a pod:
    ```bash
    kubectl get pods -n kube-system
    # Suppose you find a pod named 'coredns-xxxx-yyyy'
    kubectl logs coredns-xxxx-yyyy -n kube-system
    ```

5.  **Deploy a Sample Application:**
    ```bash
    kubectl create deployment nginx --image=nginx
    kubectl expose deployment nginx --port=80 --type=LoadBalancer # or NodePort
    kubectl get services nginx
    kubectl get pods -l app=nginx
    ```

---

**Summary of Proxy Configurations:**

*   **For `talosctl` (Talos API, port 50000, gRPC):**
    *   Use `--proxy socks5://proxy.example.com:1080` flag.
    *   Or set `TALOSCONFIG_PROXY=socks5://proxy.example.com:1080`.
    *   `ALL_PROXY=socks5://proxy.example.com:1080` might also work.
*   **For `kubectl` (Kubernetes API, port 6443, HTTPS):**
    *   Set `export HTTPS_PROXY=socks5://proxy.example.com:1080` (if SOCKS5 proxy handles HTTPS).
    *   Or `export HTTPS_PROXY=http://proxy.example.com:8080` (if it's an HTTP proxy on that port).

**Important Considerations on an Oxide Rack:**
*   **Network Configuration:** Oxide's networking model might mean your Talos nodes have IPs that are only routable within the rack or specific Oxide-defined networks. The "setup proxy" is your bridge from your management workstation into this network.
*   **Sidero Metal:** If you used Sidero Metal (the bare metal Kubernetes management platform often paired with Oxide) to provision Talos, Sidero itself might provide some of these interaction capabilities or facilitate access to `talosconfig`.

**Troubleshooting:**
*   **Connectivity:** Use `curl` or `nc` (netcat) through the proxy to test connectivity to control plane IPs on ports 50000 and 6443.
    For SOCKS5:
    ```bash
    # Test Talos API port
    curl --socks5-hostname proxy.example.com:1080 -v telnet://10.0.0.10:50000
    # Test Kubernetes API port
    curl --socks5-hostname proxy.example.com:1080 -vsk https://10.0.0.10:6443/healthz
    ```
    For HTTP proxy:
    ```bash
    # Test Kubernetes API port (HTTP proxy usually doesn't work well for arbitrary TCP like Talos API)
    curl -x http://proxy.example.com:8080 -vsk https://10.0.0.10:6443/healthz
    ```
*   **Certificates:** Ensure your `talosconfig` has the correct CA and client certificates.
*   **Firewalls:** Ensure the proxy itself can reach the Talos nodes and that no other firewalls are blocking traffic.

This comprehensive guide should allow you to effectively interact with your Talos Linux lab environment from behind a setup proxy. Remember to replace placeholder IPs, proxy addresses, and file names with your actual values.

**Resources:**
*   **Talos `talosctl` Cheatsheet:** [https://www.talos.dev/v1.7/talos-guides/talosctl-cheatsheet/](https://www.talos.dev/v1.7/talos-guides/talosctl-cheatsheet/)
*   **Talos `talosconfig` Reference:** [https://www.talos.dev/v1.7/reference/talosconfig/](https://www.talos.dev/v1.7/reference/talosconfig/)
*   **Oxide Computer:** [https://oxide.computer/](https://oxide.computer/)
*   **Sidero Metal:** [https://www.sidero.dev/](https://www.sidero.dev/)

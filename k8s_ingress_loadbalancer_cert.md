# Install Certificates for Ingress and Service type Loadbalancer

To add a public certificate to an AKS (Azure Kubernetes Service) Service that is exposed by a LoadBalancer, you have several steps to follow. This involves creating the Kubernetes resources required to obtain and manage the certificate and configuring your AKS service to use it. This answer will guide you through using a Kubernetes Ingress controller along with cert-manager to automatically issue and manage the Let's Encrypt certificate.

### Steps:

1. **Install NGINX Ingress Controller**: 
   This will handle routing external traffic to your services.
   
2. **Install cert-manager**:
   This will obtain and manage the SSL certificates for your domains.

3. **Create Issuer or ClusterIssuer**:
   It defines the certificate authority (Let's Encrypt) and how to communicate with them.

4. **Create Ingress resource**:
   This will configure routing rules and use the created certificate.

### Step-by-Step Guide:

#### 1. **Install NGINX Ingress Controller**

Install the NGINX Ingress Controller using Helm:

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
```

This will deploy the NGINX Ingress controller in your AKS cluster.

#### 2. **Install cert-manager**

Add cert-manager Helm repository and install it:

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.6.1
```

#### 3. **Create Issuer / ClusterIssuer**

Create a ClusterIssuer for Let's Encrypt:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Save this file as `cluster-issuer.yaml` and apply it:

```sh
kubectl apply -f cluster-issuer.yaml
```

#### 4. **Create Kubernetes Manifest for Pod, Service, and Ingress**

Your `julia-service` pod, service, and ingress definition might look like this:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: julia-service
  labels:
    app: julia-service
spec:
  containers:
  - name: julia-service
    image: cdsoptmzdev.azurecr.io/julia-service:141799
    imagePullPolicy: Always
    ports:
    - containerPort: 8000

---
apiVersion: v1
kind: Service
metadata:
  name: julia-service
spec:
  selector:
    app: julia-service
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
  type: LoadBalancer

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: julia-service-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: julia-service
            port:
              number: 80
  tls:
  - hosts:
    - yourdomain.com
    secretName: julia-service-tls
```

Save this combined file as `julia-service.yaml` and apply it:

```sh
kubectl apply -f julia-service.yaml
```

### Explanation:

- **Pod** definition: This defines the `julia-service` pod with the application container.
- **Service** definition: It exposes the pod on port 80 using a LoadBalancer.
- **Ingress** definition: It configures the routing rules for your service, specifies the domain `yourdomain.com`, and sets up TLS using the `letsencrypt-prod` ClusterIssuer. The `secretName` specifies where the certificate will be stored.

Ensure your domain (`yourdomain.com`) points to the external IP of the Ingress controller.

AKS service to use a public certificate from Let's Encrypt, might take a few minutes for the certificate to be issued and applied.

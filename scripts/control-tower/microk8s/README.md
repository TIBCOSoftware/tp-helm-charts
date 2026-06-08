<!-- 
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file. 
-->

# BMDP Control Tower - MicroK8s Data Plane Installation Script

This script is used to install **Bare Metal Data Plane (BMDP) for Control Tower** in a MicroK8s cluster. It provides an automated way to set up the Kubernetes environment, configure ingress/gateway controllers, and register data planes with the TIBCO Platform.

---

## Overview

The `dpinstall.sh` script is a comprehensive Bash utility that supports both **interactive** and **silent (automated)** modes for:

- Installing and managing MicroK8s Kubernetes cluster
- Deploying various Ingress Controllers (Nginx, Traefik, HAProxy)
- Deploying Gateway API Controllers (NGINX Gateway Fabric, Traefik Gateway, Istio Gateway)
- Uninstalling Ingress and Gateway Controllers
- Listing installed controllers
- Registering Data Planes with TIBCO Platform Control Tower

---

## Prerequisites

| Requirement | Description |
|-------------|-------------|
| **Operating System** | Linux (Ubuntu recommended) with `snap` package manager |
| **User** | Non-root user with sudo privileges |
| **Tools** | `kubectl`, `helm` (auto-configured when using MicroK8s) |
| **Network** | Access to Helm chart repositories and container registries |

---

## Operation Modes

### 1. Interactive Mode (Default)

Run the script without arguments to enter interactive mode:

```bash
./dpinstall.sh
```

### 2. Silent Mode

Run the script with command-line arguments for automated/scripted deployments:

```bash
./dpinstall.sh -p <sudo_password> -c <config_file> -rdp -ip <ipv4_address>
```

---

## Main Menu (Interactive Mode)

When running interactively, you'll see the following options:

```
Please choose any one of the below options:
  1) Install Kubernetes - microk8s
  2) Uninstall Kubernetes - microk8s
  3) Register Data Plane
  4) Manage Ingress / Gateway Controllers
  5) Exit
```

---

## Workflow Steps

### Step 1: Install MicroK8s Kubernetes Cluster

**What it does:**
1. Checks if Linux OS with `snap` package manager is available
2. Verifies if MicroK8s is already installed
3. Installs MicroK8s via snap (`snap install --stable --classic microk8s`)
4. Configures user permissions for MicroK8s access
5. Enables `hostpath-storage` addon for persistent volumes
6. Generates kubeconfig file at `~/.kube/_dpinstall_.yaml`
7. Creates snap aliases for `kubectl` and `helm`

**Output:**
- MicroK8s cluster running and ready
- kubectl and helm commands available
- KUBECONFIG environment variable set

---

### Step 2: Uninstall MicroK8s

**What it does:**
1. Removes MicroK8s snap package (`snap remove --purge microk8s`)
2. Cleans up all associated data

---

### Step 3: Register Data Plane

**What it does:**
1. Validates prerequisites (kubectl, helm, KUBECONFIG, running cluster)
2. Loads data plane configuration from `dpregister.env` file
3. Prompts for Ingress Controller installation based on `INGRESS_CONTROLLER` setting
4. Prompts for Gateway Controller installation based on `GATEWAY_CONTROLLER` setting
5. Generates data plane registration script
6. Executes the registration script to connect to TIBCO Platform

**Required Configuration File:** `dpregister.env`

```bash
# Example dpregister.env content
HELM_REPO="helm repo add tibco-platform https://..."
NS_CREATE="kubectl create namespace dp-namespace --dry-run=client -o yaml | kubectl apply -f -"
SA_CREATE="kubectl create serviceaccount dp-sa -n dp-namespace"
REG_COMMAND="helm install dp-registration tibco-platform/dp-registration ..."
INGRESS_CLASS_NAME="nginx"
INGRESS_CONTROLLER="nginx"
GATEWAY_NAME="nginx-gateway"
GATEWAY_CONTROLLER="nginx-gateway-fabric"
```

---

### Step 4: Manage Ingress / Gateway Controllers

**Sub-menu options:**

```
Manage Ingress / Gateway Controllers:
  1) Install New Controller
  2) Uninstall Controller
  3) List Installed Controllers
  4) Back to main menu
```

---

## Supported Ingress Controllers

| Controller | Helm Chart | IngressClass | Namespace |
|------------|------------|--------------|-----------|
| **Nginx** | `ingress-nginx/ingress-nginx` | `nginx` | `ingress` |
| **Traefik** | `traefik/traefik` | `traefik` | `ingress` |
| **HAProxy** | `haproxy/kubernetes-ingress` | `haproxy` | `ingress` |

### Installation Details

**Nginx Ingress Controller:**
```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --set controller.ingressClassResource.name=nginx \
  --set "controller.service.externalIPs[0]=<MACHINE_IP>" \
  --namespace ingress --create-namespace
```

**Traefik Ingress Controller:**
```bash
helm upgrade --install traefik traefik/traefik \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=false \
  --set ingressClass.name=traefik \
  --set "service.spec.externalIPs[0]=<MACHINE_IP>" \
  --namespace ingress --create-namespace
```

**HAProxy Ingress Controller:**
```bash
helm upgrade --install haproxy-ingress haproxy/kubernetes-ingress \
  --set controller.ingressClassResource.name=haproxy \
  --set controller.service.type=LoadBalancer \
  --set "controller.service.externalIPs[0]=<MACHINE_IP>" \
  --namespace ingress --create-namespace
```

---

## Supported Gateway Controllers

| Controller | GatewayClass | Gateway Name | Namespace |
|------------|--------------|--------------|-----------|
| **NGINX Gateway Fabric** | `nginx` | `nginx-gateway` | `nginx-gateway` |
| **Traefik Gateway** | `traefik` | `traefik-gateway` | `traefik-gateway` |
| **Istio Gateway** | `istio` | `istio-gateway` | `istio-gateway` |

### Installation Details

All Gateway Controllers install:
1. **Gateway API CRDs** from `kubernetes-sigs/gateway-api` (v1.4.1)
2. **Controller-specific Helm chart**
3. **Gateway resource** with external IP configuration

**NGINX Gateway Fabric:**
```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
helm upgrade --install nginx-gateway-fabric oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway --create-namespace
```

**Traefik Gateway Controller:**
```bash
helm upgrade --install traefik-gateway traefik/traefik \
  --namespace traefik-gateway --create-namespace \
  --set providers.kubernetesGateway.enabled=true \
  --set gateway.enabled=false \
  --set ingressClass.enabled=false \
  --set service.spec.externalIPs[0]="<MACHINE_IP>"
```

**Istio Gateway Controller:**
```bash
helm upgrade --install istio-base istio/base --namespace istio-system --create-namespace
helm upgrade --install istiod istio/istiod --namespace istio-system
kubectl create namespace istio-gateway
# Gateway resource created with external IP
```

---

## Command Line Options

| Option | Description |
|--------|-------------|
| `[no arguments]` | Interactive Mode |
| `help`, `-h`, `--help` | Print usage information |
| `-c`, `--config <path>` | Data plane config file path (default: `$PWD/dpregister.env`) |
| `-p`, `--pass`, `--password`, `-su`, `--sudo <password>` | Sudo password for silent mode |
| `-ss`, `--show-status` | Show cluster status |
| `-ik8s`, `--installk8s`, `--install-kubernetes` | Install MicroK8s |
| `-rk8s`, `--removek8s`, `--remove-kubernetes` | Remove MicroK8s |
| `-type`, `--k8stype <type>` | Kubernetes type (default: `microk8s`) |
| `-rdp`, `--register-dp`, `--register-data-plane` | Register data plane |
| `-sk`, `--skip-ngxc`, `--skip-nginx-controller` | Skip ingress controller installation |
| `-ip`, `--ipv4`, `--ip-addr-ingress-controller <ip>` | IPv4 address for ingress controller |

---

## Usage Examples

### Interactive Mode
```bash
# Run with default config
./dpinstall.sh

# Run with custom config file
./dpinstall.sh -c /path/to/dpregister.env
```

### Silent Mode - Install MicroK8s
```bash
./dpinstall.sh -p "mysudopassword" -ik8s -type microk8s
```

### Silent Mode - Remove MicroK8s
```bash
./dpinstall.sh -p "mysudopassword" -rk8s -type microk8s
```

### Silent Mode - Register Data Plane with Ingress Controller
```bash
./dpinstall.sh -p "mysudopassword" -c ./dpregister.env -rdp -ip 192.168.1.100
```

### Silent Mode - Register Data Plane (Skip Ingress Controller)
```bash
./dpinstall.sh -p "mysudopassword" -c ./dpregister.env -rdp -sk
```

### Silent Mode - Show Status
```bash
./dpinstall.sh -p "mysudopassword" -ss
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `KUBECONFIG` | Path to Kubernetes config file |
| `DPCLI_KUBECONFIG` | MicroK8s-generated kubeconfig (`~/.kube/_dpinstall_.yaml`) |
| `DATAPLANE_CONFIG` | Path to data plane configuration file |
| `INGRESS_IP` | IPv4 address for ingress controller |
| `K8S_TYPE` | Kubernetes distribution type (default: `microk8s`) |
| `SKIP_NGINX_CONTROLLER` | Set to `true` to skip ingress controller installation |

---

## Configuration File Format (dpregister.env)

```bash
# Helm repository configuration
HELM_REPO="helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts"

# Namespace creation command
NS_CREATE="kubectl create namespace <namespace> ..."

# Service account creation command
SA_CREATE="kubectl create serviceaccount <sa-name> -n <namespace>"

# Data plane registration Helm command
REG_COMMAND="helm install <release-name> tibco-platform/<chart> ..."

# Ingress configuration
INGRESS_CLASS_NAME="nginx"           # nginx | traefik | haproxy
INGRESS_CONTROLLER="nginx"           # nginx | traefik | haproxy

# Gateway configuration (optional)
GATEWAY_NAME="nginx-gateway"         # nginx-gateway | traefik-gateway | istio-gateway
GATEWAY_CONTROLLER="nginx-gateway-fabric"  # nginx-gateway-fabric | traefik-gateway | istio-gateway
```

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     dpinstall.sh                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ Interactive  │    │    Silent    │    │     Help     │      │
│  │    Mode      │    │     Mode     │    │              │      │
│  └──────┬───────┘    └──────┬───────┘    └──────────────┘      │
│         │                   │                                   │
│         ▼                   ▼                                   │
│  ┌──────────────────────────────────────────────────────┐      │
│  │                    Main Menu                          │      │
│  ├──────────────────────────────────────────────────────┤      │
│  │ 1) Install K8s    2) Uninstall K8s                   │      │
│  │ 3) Register DP    4) Manage Controllers              │      │
│  └──────────────────────────────────────────────────────┘      │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────────────────────────────────────────────┐      │
│  │              Register Data Plane Flow                 │      │
│  ├──────────────────────────────────────────────────────┤      │
│  │ 1. Check Prerequisites (kubectl, helm, KUBECONFIG)   │      │
│  │ 2. Load dpregister.env configuration                 │      │
│  │ 3. Install Ingress Controller (if specified)         │      │
│  │ 4. Install Gateway Controller (if specified)         │      │
│  │ 5. Generate registration script                      │      │
│  │ 6. Execute registration with TIBCO Platform          │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **"snap package manager is not installed"** | Install snap: `sudo apt install snapd` |
| **"kubectl command not found"** | Run option 1 to install MicroK8s, or create snap alias |
| **"KUBECONFIG file not found"** | Run `microk8s config > ~/.kube/_dpinstall_.yaml` |
| **"microk8s is not running"** | Run `sudo microk8s start` |
| **"Permission denied"** | Ensure user is in microk8s group: `sudo usermod -a -G microk8s $USER` |
| **Ingress controller not accessible** | Verify external IP is correct and firewall allows traffic |
| **Gateway not routing traffic** | Check Gateway and HTTPRoute resources: `kubectl get gateway,httproute -A` |

---

## Post-Installation

After successful data plane registration:

1. **Verify cluster status:**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   kubectl get pods -A
   ```

2. **Check ingress controller:**
   ```bash
   kubectl get ingressclass
   kubectl get svc -n ingress
   ```

3. **Check gateway controller (if installed):**
   ```bash
   kubectl get gatewayclass
   kubectl get gateway -A
   ```

4. **Verify data plane registration:**
   - Log in to TIBCO Platform Control Tower
   - Navigate to Data Planes section
   - Confirm the registered data plane appears and is healthy

---

## Notes

- This script must be run as a **non-root user** with sudo privileges
- MicroK8s is installed via snap in **classic** confinement mode
- The script automatically enables `hostpath-storage` addon for persistent storage
- For production environments, consider using a cloud-managed Kubernetes service
- DNS or `/etc/hosts` entry is required for FQDN-based ingress access

# Crossplane Configuration

This directory contains cluster-scoped Crossplane resources and provider configurations.

## Contents

- `namespace.yaml` - Namespace for Machine claims
- `providerconfig-proxmox.yaml` - ProviderConfig for provider-proxmox-bpg
- `providerconfig-terraform.yaml` - Alternative: ProviderConfig for Terraform provider (legacy)

## Provider

This setup uses **[provider-proxmox-bpg](https://marketplace.upbound.io/providers/valkiriaaquaticamendi/provider-proxmox-bpg/v1.3.0)** - a native Crossplane provider based on the [bpg/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox) Terraform provider.

**Benefits:**
- Native Crossplane integration (simpler than provider-terraform)
- Actively maintained and auto-syncs with upstream
- Full Crossplane v2.0+ support
- 63 managed resources

## Setup Steps

### 1. Install Crossplane

```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

helm install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace

# Wait for Crossplane to be ready
kubectl wait --for=condition=ready pod \
  -l app=crossplane \
  -n crossplane-system \
  --timeout=300s
```

### 2. Install Provider

```bash
# Install provider-proxmox-bpg
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-proxmox-bpg
spec:
  package: xpkg.upbound.io/valkiriaaquaticamendi/provider-proxmox-bpg:v1.3.0
EOF

# Wait for provider to be ready
kubectl wait --for=condition=healthy provider/provider-proxmox-bpg --timeout=300s
```

**Alternative:** Terraform provider (if you prefer)
```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-terraform
spec:
  package: xpkg.upbound.io/upbound/provider-terraform:v0.13.0
EOF
# Then use crossplane/config/providerconfig-terraform.yaml
```

### 3. Create Proxmox Credentials Secret

#### For provider-proxmox-bpg:

```bash
# Create secret with Proxmox API credentials
kubectl create secret generic proxmox-creds \
  --namespace crossplane-system \
  --from-literal=credentials='{
    "endpoint": "https://proxmox.example.com:8006",
    "username": "root@pam",
    "password": "your-password",
    "insecure": true
  }'
```

**Or with API token (recommended):**
```bash
kubectl create secret generic proxmox-creds \
  --namespace crossplane-system \
  --from-literal=credentials='{
    "endpoint": "https://proxmox.example.com:8006",
    "api_token": "root@pam!mytoken=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "insecure": true
  }'
```

**How to create Proxmox API token:**

1. Log into Proxmox web UI
2. Go to Datacenter → Permissions → API Tokens
3. Click "Add" to create a new token
4. User: `root@pam` (or create a dedicated user)
5. Token ID: `mytoken` (or your choice)
6. Uncheck "Privilege Separation" for full permissions (or configure granular permissions)
7. Copy the full token value (format: `user@realm!tokenid=secret`) - you won't see it again!

**For provider-terraform (legacy):**
```bash
kubectl create secret generic proxmox-creds \
  --namespace crossplane-system \
  --from-literal=credentials='{
    "pm_api_url": "https://proxmox.example.com:8006/api2/json",
    "pm_api_token_id": "terraform@pve!mytoken",
    "pm_api_token_secret": "your-secret-here",
    "pm_tls_insecure": true
  }'
```

### 4. Apply ProviderConfig

```bash
# For provider-proxmox-bpg (default)
kubectl apply -f config/providerconfig-proxmox.yaml

# OR for Terraform provider (legacy)
kubectl apply -f config/providerconfig-terraform.yaml

# Verify
kubectl get providerconfig
```

### 5. Create Namespace for Machines

```bash
kubectl apply -f config/namespace.yaml

# Verify
kubectl get namespace infra-machines
```

### 6. Install Machine API Package

```bash
# Apply the XRD and Composition
kubectl apply -f ../package/xrd.yaml
kubectl apply -f ../package/composition.yaml

# Verify
kubectl get xrd
kubectl get composition
```

## Verify Installation

Run these checks to ensure everything is ready:

```bash
# 1. Crossplane is running
kubectl get pods -n crossplane-system
#    Should show crossplane pods in Running state

# 2. Provider is installed and healthy
kubectl get providers
#    Should show your provider with INSTALLED=True and HEALTHY=True

# 3. ProviderConfig exists
kubectl get providerconfig
#    Should show "default" config

# 4. XRD is installed
kubectl get xrd xmachines.infra.kubelize.io
#    Should show the XMachine XRD with ESTABLISHED=True

# 5. Composition exists
kubectl get composition
#    Should show xmachine.infra.kubelize.io composition

# 6. Namespace exists
kubectl get namespace infra-machines
#    Should show the namespace
```

If all checks pass, you're ready to create Machine claims!

## Testing Provider Connection

### Test provider-proxmox-bpg

```bash
# Check provider status
kubectl get providers
# Should show provider-proxmox-bpg as INSTALLED=True and HEALTHY=True

# Check provider pods
kubectl get pods -n crossplane-system | grep proxmox

# View provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-proxmox-bpg -f

# Test with a simple resource (optional - clean up after)
# You can create a test VM or just verify the ProviderConfig is working by creating a Machine claim
```

## Troubleshooting

### Provider Not Healthy

```bash
# Check provider status
kubectl get providers
kubectl describe provider <provider-name>

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=<provider-name> -f
```

### ProviderConfig Issues

```bash
# Check ProviderConfig
kubectl describe providerconfig default

# Verify secret exists
kubectl get secret proxmox-creds -n crossplane-system

# Check secret contents (be careful - contains credentials!)
kubectl get secret proxmox-creds -n crossplane-system -o jsonpath='{.data.credentials}' | base64 -d
```

### Proxmox API Connection Issues

Common issues:
1. **Certificate validation**: Set `pm_tls_insecure: true` for self-signed certs
2. **API endpoint**: Ensure URL is correct and accessible from cluster
3. **Token permissions**: Ensure token has necessary permissions (VM.*, Datastore.*, etc.)
4. **Firewall**: Ensure cluster can reach Proxmox API (port 8006)

Test from a pod:
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -k https://proxmox.example.com:8006/api2/json/version
```

### XRD Not Installing

```bash
# Check for validation errors
kubectl describe xrd xmachines.infra.kubelize.io

# Check Crossplane logs
kubectl logs -n crossplane-system -l app=crossplane -f
```

## Updating Configuration

### Update Credentials

```bash
# Delete old secret
kubectl delete secret proxmox-creds -n crossplane-system

# Create new secret with updated credentials
kubectl create secret generic proxmox-creds \
  --namespace crossplane-system \
  --from-literal=credentials='{...}'

# Restart provider to pick up changes
kubectl delete pods -n crossplane-system -l pkg.crossplane.io/provider=provider-terraform
```

### Update ProviderConfig

```bash
# Edit the ProviderConfig
kubectl edit providerconfig default

# Or re-apply from file
kubectl apply -f config/providerconfig-terraform.yaml
```

## Security Best Practices

1. **Use API Tokens**: Prefer API tokens over username/password
2. **Least Privilege**: Grant only necessary permissions to Proxmox user
3. **Rotate Credentials**: Periodically rotate API tokens
4. **Sealed Secrets**: Consider using SealedSecrets or External Secrets Operator for production
5. **Network Policies**: Restrict network access to Crossplane pods
6. **RBAC**: Configure Kubernetes RBAC for Machine claim creation

## Advanced: Multiple Proxmox Clusters

To manage VMs across multiple Proxmox clusters:

1. Create multiple ProviderConfigs:
```bash
kubectl apply -f - <<EOF
apiVersion: tf.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: proxmox-cluster-1
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: proxmox-cluster-1-creds
      key: credentials
---
apiVersion: tf.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: proxmox-cluster-2
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: proxmox-cluster-2-creds
      key: credentials
EOF
```

2. Reference in Machine claims:
```yaml
apiVersion: infra.kubelize.io/v1alpha1
kind: Machine
metadata:
  name: my-vm
spec:
  # ... other fields ...
  compositionSelector:
    matchLabels:
      cluster: cluster-1
  # Or use providerConfigRef if supported by your composition
```

3. Update Composition to support multiple ProviderConfigs

## See Also

- [../package/README.md](../package/README.md) - Package customization
- [Crossplane Provider Installation](https://docs.crossplane.io/latest/concepts/providers/)
- [Crossplane ProviderConfig](https://docs.crossplane.io/latest/concepts/providers/#provider-configuration)

# Infrastructure Template - Rancher Management Cluster

Reusable Terraform/OpenTofu template for provisioning HA RKE2 clusters **specifically configured for Rancher management cluster deployments**.

**⚠️ TEMPLATE ONLY** - Copy and customize before use.

**Note:** This template is Rancher-oriented. It configures DNS, domains, and outputs specifically for Rancher Server deployment. For generic Kubernetes clusters, adapt the DNS configuration and remove Rancher-specific outputs.

## Current Configuration

- **Purpose:** Rancher Management Cluster
- **Cloud Provider:** Hetzner Cloud
- **DNS Provider:** Cloudflare
- **Kubernetes:** RKE2 (HA, 3+ nodes)
- **CNI:** Cilium
- **Ingress:** Traefik (via Helm)
- **DNS Setup:** `rancher.yourdomain.com` (Round Robin) - Optional Load Balancer available

**Note:** This template is Rancher-oriented and currently vendor-specific (Hetzner + Cloudflare). To use other providers, update the provider blocks in `providers.tf` and corresponding resources in `main.tf`. See inline comments marked with `NOTE:` for guidance.

## Quick Start

1. **Copy template:**
```bash
cp -r infra-template-rancher-management your-repo-name
cd your-repo-name
```

2. **Set API tokens (mandatory):**
```bash
export TF_VAR_hcloud_token="your-hetzner-token"
export TF_VAR_cloudflare_api_token="your-cloudflare-token"
```

3. **Configure variables:**
```bash
cat > terraform.tfvars << EOF
domain_name       = "yourdomain.com"
ssh_key_path      = "~/.ssh/id_rsa.pub"
letsencrypt_email = "admin@yourdomain.com"
cluster_name      = "my-cluster"
EOF
```

3. **Review the Makefile:**
   Check `Makefile` to see available commands and how Terraform/OpenTofu outputs are mapped to Ansible playbooks. Key targets include infrastructure management (`init`, `plan`, `apply`, `destroy`) and service deployment (`deploy-traefik`, `deploy-cert-manager`, `deploy-rancher`, `deploy-all`). Run `make help` for a complete list.

4. **⚠️ Note on ci-cd-templates repository:**
   This template assumes a sibling [ci-cd-templates](https://github.com/bmsj5/ci-cd-templates) directory containing Ansible playbooks and Helm charts. The Makefile references [ci-cd-templates/ansible](https://github.com/bmsj5/ci-cd-templates/tree/main/ansible) for deployment playbooks and [ci-cd-templates/helm-charts](https://github.com/bmsj5/ci-cd-templates/tree/main/helm-charts) for Helm chart values. Ensure this repository structure exists or adjust the paths in `Makefile`.

5. **Deploy infrastructure:**
```bash
make init
make plan
make apply
```

## RKE2 Version Compatibility

**Rancher 2.13.x supports:**
- RKE2 v1.34.x (latest supported: `v1.34.2+rke2r1`)

**Current default:** `v1.34.2+rke2r1` (compatible with Rancher 2.13.x)

Check [Rancher's support matrix](https://rancher.com/support-matrix/) for the latest compatibility information.

## Prerequisites

- OpenTofu >= 1.0 (or Terraform >= 1.0)
- Ansible >= 2.9
- Helm >= 3.0
- `jq` (for Makefile)
- SSH key pair
- Cloud provider API token
- DNS provider API token

## Python Dependencies (for Ansible)

```bash
pip install kubernetes
```

## Makefile Targets

### Infrastructure Management
- `make init` - Initialize Terraform/OpenTofu
- `make plan` - Preview changes (runs with `-lock=false`)
- `make apply` - Deploy infrastructure (runs with `-auto-approve -lock=false`)
- `make destroy` - Destroy infrastructure (runs with `-auto-approve -lock=false`)
### Environment Setup
- `eval $(make setup-env)` - Set environment variables in your shell. **Important:** Make runs in a subprocess and cannot modify the parent shell's environment variables. Use `eval $(make setup-env)` to execute the export commands in your current shell session. This sets `KUBECONFIG`, `DOMAIN_NAME`, `LETS_ENCRYPT_EMAIL`, `RANCHER_BOOTSTRAP_PASSWORD`, and `HELM_CHARTS_PATH`.

### Service Deployment
- `make deploy-traefik` - Deploy Traefik ingress controller via Ansible
- `make deploy-cert-manager` - Deploy cert-manager via Ansible
- `make deploy-rancher` - Deploy Rancher server via Ansible
- `make deploy-all` - Deploy all services in order (Traefik → cert-manager → Rancher)

## Adapting for Other Providers

1. **Cloud Provider:**
   - Replace `hcloud_*` resources in `main.tf` with your provider's resources
   - Update `providers.tf` with your provider's configuration
   - Update `variables.tf` to match your provider's requirements

2. **DNS Provider:**
   - Replace `cloudflare_*` resources in `main.tf` with your DNS provider's resources
   - Update `providers.tf` with your DNS provider's configuration

3. **Outputs:**
   - Ensure `outputs.tf` matches what your Ansible playbooks expect
   - Update `Makefile` if output names differ

## What It Creates

- 3+ Hetzner Cloud servers (Debian 13)
- HA RKE2 cluster (Cilium CNI)
- Cloudflare DNS A records for `rancher.yourdomain.com` (Round Robin)
- Local kubeconfig file (`output/kubeconfig.yaml`)
- Rancher bootstrap password (random, stored in Terraform state)
- Infrastructure ready for Rancher Server deployment via `make deploy-rancher`

## Load Balancer Option

**Default:** DNS round-robin A records (free, basic HA) - `enable_load_balancer = false`

**Optional:** Hetzner Cloud Load Balancer (Layer-4 TCP, ~€6/month, production-grade HA) - `enable_load_balancer = true`

The template uses conditional logic based on the `enable_load_balancer` variable. This provides:
- ✅ Health checks with automatic failover
- ✅ Better WebSocket support for Rancher
- ✅ Immediate node failure detection
- ✅ Production-grade high availability

**To enable the load balancer:**

Add to your `terraform.tfvars`:
```hcl
enable_load_balancer = true
```

**Note:** Rancher documentation recommends using a Layer-4/7 load balancer for production HA deployments. DNS round-robin works for development/testing but lacks health checks and immediate failover capabilities.

## Next Steps

After `make apply`:

1. **Set up your shell environment:**
   ```bash
   eval $(make setup-env)
   ```
   This configures `KUBECONFIG` and other required environment variables right in your shell.

2. **Verify cluster connectivity:**
   ```bash
   kubectl get nodes
   ```

3. **Deploy services:**
   ```bash
   make deploy-all
   ```
   This deploys Traefik, cert-manager, and Rancher in sequence.

4. **Access Rancher:**
   - URL: `https://rancher.yourdomain.com`

## Support

- [Hetzner Cloud Docs](https://docs.hetzner.cloud)
- [RKE2 Docs](https://docs.rke2.io)
- [Rancher Support Matrix](https://rancher.com/support-matrix/)
- [OpenTofu Docs](https://opentofu.org)

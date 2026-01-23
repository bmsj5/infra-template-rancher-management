# Infrastructure Template - Rancher Management Cluster

Reusable Terraform/OpenTofu template for provisioning HA RKE2 clusters **specifically configured for Rancher management cluster deployments**.

**⚠️ TEMPLATE ONLY** - Copy and customize before use.

⚠️ This template is Rancher-oriented. It configures DNS, domains, and outputs specifically for Rancher Server deployment. For generic Kubernetes clusters, adapt the DNS configuration and remove Rancher-specific outputs.

## Current Configuration

- **Cloud Provider:** Hetzner Cloud
- **DNS Provider:** Cloudflare
- **DNS Setup:** `rancher.yourdomain.com` (Round Robin) - Optional Load Balancer available
- **Kubernetes:** RKE2 (HA, 3+ nodes)
- **CNI:** Cilium
- **Ingress:** Traefik (via Helm)
- **Certificate Management:** cert-manager (Let's Encrypt, via Helm) 
- **Rancher:** Rancher Server (via Helm)

⚠️ This template is Rancher-oriented and currently vendor-specific (Hetzner + Cloudflare). To use other providers, you will have to change the code significantly.

## RKE2 Version Compatibility

**Rancher 2.13.x supports:**
- RKE2 v1.34.x (latest supported: `v1.34.2+rke2r1`)

**Current default:** `v1.34.2+rke2r1` (compatible with Rancher 2.13.x)

Check [Rancher's support matrix](https://rancher.com/support-matrix/) for the latest compatibility information.

## Prerequisites

**Tools:**
- OpenTofu >= 1.0 (or Terraform >= 1.0)
- Python >= 3.6 (required for Ansible)
- Ansible >= 2.9
- Helm >= 3.0
- `jq` (for Makefile)

**Credentials:**
- SSH key pair
- Cloud provider API token
- DNS provider API token

## Python Dependencies (for Ansible)

```bash
pip install kubernetes
```

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
   Copy/Rename to "terraform.tfvars" and customize this file [`terraform.tfvars.example`](terraform.tfvars.example) for your environment:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```
   See [`variables.tf`](variables.tf) for a complete list of available variables.

3. **Review the Makefile:**
   Check [`Makefile`](Makefile) to see available commands and how Terraform/OpenTofu outputs are mapped to Ansible playbooks. Key targets include infrastructure management (`init`, `plan`, `apply`, `destroy`) and service deployment (`deploy-traefik`, `deploy-cert-manager`, `deploy-rancher`, `deploy-all`). Run `make help` for a complete list.

4. **⚠️ Note on ci-cd-templates repository:**
   This template assumes a sibling [ci-cd-templates](https://github.com/bmsj5/ci-cd-templates) directory containing Ansible playbooks and Helm charts. The Makefile references [ci-cd-templates/ansible](https://github.com/bmsj5/ci-cd-templates/tree/main/ansible) for deployment playbooks and [ci-cd-templates/helm-charts](https://github.com/bmsj5/ci-cd-templates/tree/main/helm-charts) for Helm chart values. Ensure this repository structure exists or adjust the paths in `Makefile`.

5. **Deploy infrastructure:**
```bash
make init
make plan
make apply
```

6. **Deploy services:**
   - After `make apply` completes, your infrastructure is ready and you can immediately proceed with service deployment using:
   - `make deploy-all` - Deploy all services (Traefik → cert-manager → Rancher)
   - `make deploy-traefik` - Deploy Traefik only
   - `make deploy-cert-manager` - Deploy cert-manager only
   - `make deploy-rancher` - Deploy Rancher only

## Makefile Targets

### Infrastructure Management
- `make init` - Initialize Terraform/OpenTofu
- `make plan` - Preview changes (runs with `-lock=false`)
- `make apply` - Deploy infrastructure (runs with `-auto-approve -lock=false`)
- `make destroy` - Destroy infrastructure (runs with `-auto-approve -lock=false`)
### Environment Setup
- `eval $(make setup-env)` - Set environment variables in your shell. **Important:** Make runs in a subprocess and cannot modify the parent shell's environment variables. Use `eval $(make setup-env)` to execute the export commands in your current shell session. This sets `KUBECONFIG`, `DOMAIN_NAME`, `LETS_ENCRYPT_EMAIL`, `RANCHER_BOOTSTRAP_PASSWORD`, and `HELM_CHARTS_PATH`.

### Service Deployment
- `make deploy-all` - Deploy all services in order (Traefik → cert-manager → Rancher)
- `make deploy-traefik` - Deploy Traefik ingress controller via Ansible
- `make deploy-cert-manager` - Deploy cert-manager via Ansible
- `make deploy-rancher` - Deploy Rancher server via Ansible

## Outputs

All outputs are exported to `.terraform-outputs.json` and automatically set in Ansible playbooks via the Makefile.

See [`outputs.tf`](outputs.tf) for a complete list of available outputs.

## Load Balancer Option

**Default:** DNS round-robin A records (free, basic HA) - `enable_load_balancer = false`

**Optional:** Hetzner Cloud Load Balancer (Layer-4 TCP, ~€8/month, production-grade HA) - `enable_load_balancer = true`

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

## Support

- [Hetzner Cloud Docs](https://docs.hetzner.cloud)
- [RKE2 Docs](https://docs.rke2.io)
- [Rancher Support Matrix](https://rancher.com/support-matrix/)
- [OpenTofu Docs](https://opentofu.org)

# =============================================================================
# Infrastructure Template - Rancher Management Cluster
# =============================================================================
# This template provisions an HA RKE2 cluster specifically configured for
# Rancher Server deployment. It sets up DNS records, domains, and outputs
# oriented toward Rancher management clusters.
#
# Currently configured for Hetzner Cloud + Cloudflare DNS.
# 
# To adapt for other providers:
# - Replace hcloud_* resources with your cloud provider's resources
# - Replace cloudflare_* resources with your DNS provider's resources
# - Update variables.tf to match your provider's requirements
#
# To adapt for non-Rancher use:
# - Update DNS record names (currently "rancher" subdomain)
# - Remove Rancher-specific outputs (rancher_bootstrap_password, rancher_url)
# - Adjust domain configuration as needed
# =============================================================================

# -----------------------------------------------------------------------------
# SSH Key Management
# -----------------------------------------------------------------------------
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_key_path)
}

# NOTE: Cloud provider specific - currently Hetzner Cloud
# Replace with your provider's SSH key resource
resource "hcloud_ssh_key" "default" {
  name       = "${var.cluster_name}-ssh-key"
  public_key = data.local_file.ssh_public_key.content
}

# -----------------------------------------------------------------------------
# RKE2 Cluster Token
# -----------------------------------------------------------------------------
resource "random_password" "rke2_token" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# -----------------------------------------------------------------------------
# GKE-style kubelet system-reserved CPU (by server type vCPU count)
# -----------------------------------------------------------------------------
# The formula: 1->60m, 2->70m, 3->75m, 4->80m, 5+->80+floor((n-4)*2.5)m
locals {
  server_type_cpus = {
    "cx23" = 2
    "cx33" = 4
    "cx43" = 8
    "cx53" = 16
    "cpx22" = 2
    "cpx32" = 4
    "cpx42" = 8
    "cpx52" = 16
    "cpx62" = 32
    "ccx13" = 2
    "ccx23" = 4
    "ccx33" = 8
    "ccx43" = 16
    "ccx53" = 32
    "ccx63" = 64
  }
  reserved_cpu_m = {
    for k, c in local.server_type_cpus : k => (
      c == 1 ? 60 : (c == 2 ? 70 : (c == 3 ? 75 : (c == 4 ? 80 : 80 + floor((c - 4) * 2.5))))
    )
  }
}

# -----------------------------------------------------------------------------
# RKE2 HA Cluster Nodes
# -----------------------------------------------------------------------------
# NOTE: Cloud provider specific - currently Hetzner Cloud
# Replace hcloud_server with your provider's compute resource
resource "hcloud_server" "rke2_nodes" {
  count       = var.node_count
  name        = "${var.cluster_name}-node-${count.index + 1}"
  image       = "debian-13"
  server_type = var.server_type
  location    = var.region
  ssh_keys    = [hcloud_ssh_key.default.id]

  user_data = templatefile("${path.module}/templates/user-data.yaml.tpl", {
    node_index       = count.index
    node_count       = var.node_count
    cluster_token    = random_password.rke2_token.result
    node_hostname    = "${var.cluster_name}-node-${count.index + 1}"
    ssh_public_key   = data.local_file.ssh_public_key.content
    cluster_domain   = "rancher.${var.domain_name}"
    rke2_version     = var.rke2_version
    reserved_cpu_m   = local.reserved_cpu_m[var.server_type]
  })
}

# -----------------------------------------------------------------------------
# DNS Records (Round Robin)
# -----------------------------------------------------------------------------
# NOTE: DNS provider specific - currently Cloudflare
# Replace cloudflare_* resources with your DNS provider's resources
data "cloudflare_zone" "domain" {
  filter = {
    name = var.domain_name
  }
}

# -----------------------------------------------------------------------------
# DNS Records (Round Robin) - Used when load balancer is disabled
# -----------------------------------------------------------------------------
resource "cloudflare_dns_record" "rke2_nodes" {
  count   = var.enable_load_balancer ? 0 : var.node_count
  zone_id = data.cloudflare_zone.domain.zone_id
  name    = "rancher"
  type    = "A"
  content = hcloud_server.rke2_nodes[count.index].ipv4_address
  ttl     = 300
  proxied = false

  depends_on = [hcloud_server.rke2_nodes]
}

# -----------------------------------------------------------------------------
# OPTIONAL: Hetzner Cloud Load Balancer (Layer-4 TCP)
# -----------------------------------------------------------------------------
# Set enable_load_balancer = true in terraform.tfvars to use this instead of
# DNS round-robin. Provides production-grade HA with health checks and automatic
# failover. Recommended for production deployments.
#
# Cost: ~€5.83/month for lb11 type
#
# NOTE: Cloud provider specific - currently Hetzner Cloud
# Replace hcloud_load_balancer_* resources with your provider's load balancer
# -----------------------------------------------------------------------------
resource "hcloud_load_balancer" "rancher" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "${var.cluster_name}-lb"
  load_balancer_type = "lb11" # - sufficient for Layer-4
  location           = var.region

  labels = {
    purpose = "rancher-ha"
    cluster = var.cluster_name
  }
}

# Load Balancer Target: Attach all RKE2 nodes
resource "hcloud_load_balancer_target" "rancher_nodes" {
  count            = var.enable_load_balancer ? var.node_count : 0
  type             = "server"
  load_balancer_id = hcloud_load_balancer.rancher[0].id
  server_id        = hcloud_server.rke2_nodes[count.index].id
  use_private_ip   = false
}

# HTTP Service (port 80)
resource "hcloud_load_balancer_service" "http" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.rancher[0].id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 80

  health_check {
    protocol = "tcp"
    port     = 80
    interval = 10
    timeout  = 5
    retries  = 3
  }
}

# HTTPS Service (port 443)
resource "hcloud_load_balancer_service" "https" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.rancher[0].id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 443

  health_check {
    protocol = "tcp"
    port     = 443
    interval = 10
    timeout  = 5
    retries  = 3
  }
}

# DNS Record pointing to Load Balancer (used when load balancer is enabled)
resource "cloudflare_dns_record" "rancher" {
  count    = var.enable_load_balancer ? 1 : 0
  zone_id  = data.cloudflare_zone.domain.zone_id
  name     = "rancher"
  type     = "A"
  content  = hcloud_load_balancer.rancher[0].ipv4
  ttl      = 300
  proxied  = false

  depends_on = [hcloud_load_balancer.rancher]
}

# -----------------------------------------------------------------------------
# Wait for Cluster Stability Before Follower Updates
# -----------------------------------------------------------------------------
resource "null_resource" "wait_for_cluster_stability" {
  depends_on = [hcloud_server.rke2_nodes]

  provisioner "local-exec" {
    command = "echo '⏳ Waiting 60 seconds for cluster leader to stabilize before updating followers...' && sleep 60"
  }
}

# -----------------------------------------------------------------------------
# Configure Follower Nodes to Join Cluster
# -----------------------------------------------------------------------------
resource "null_resource" "configure_follower_nodes" {
  count      = var.node_count > 1 ? var.node_count - 1 : 0
  depends_on = [null_resource.wait_for_cluster_stability]

  connection {
    type        = "ssh"
    host        = hcloud_server.rke2_nodes[count.index + 1].ipv4_address
    user        = "root"
    private_key = file(pathexpand(replace(var.ssh_key_path, ".pub", "")))
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",

      "echo 'Updating follower node ${count.index + 2} configuration...'",
      "LEADER_IP=${hcloud_server.rke2_nodes[0].ipv4_address}",
      "echo \"Leader IP: $LEADER_IP\"",

      # Append join configuration
      "echo \"server: https://$LEADER_IP:9345\" >> /etc/rancher/rke2/config.yaml",

      # Start RKE2 for the first time
      "systemctl enable --now rke2-server",
      "echo 'Follower node updated and joining cluster'"
    ]
  }

  triggers = {
    leader_ip   = hcloud_server.rke2_nodes[0].ipv4_address
    follower_id = hcloud_server.rke2_nodes[count.index + 1].id
  }
}

# -----------------------------------------------------------------------------
# Fetch and Prepare Kubeconfig
# -----------------------------------------------------------------------------
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.configure_follower_nodes]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/output
      ssh -i ${pathexpand(replace(var.ssh_key_path, ".pub", ""))} \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=10 \
          root@${hcloud_server.rke2_nodes[0].ipv4_address} \
          "cat /etc/rancher/rke2/rke2.yaml" > ${path.module}/output/kubeconfig.yaml

      sed -i "s|127.0.0.1:6443|${hcloud_server.rke2_nodes[0].ipv4_address}:6443|g" ${path.module}/output/kubeconfig.yaml
    EOT
  }

  triggers = {
    leader_ip = hcloud_server.rke2_nodes[0].ipv4_address
  }
}

# -----------------------------------------------------------------------------
# Rancher Bootstrap Password
# -----------------------------------------------------------------------------
resource "random_password" "rancher_bootstrap" {
  length  = 24
  special = true
  upper   = true
  lower   = true
  numeric = true
}

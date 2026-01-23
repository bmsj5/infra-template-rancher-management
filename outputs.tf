# =============================================================================
# Outputs
# =============================================================================
# These outputs are consumed by Ansible playbooks via the Makefile.
# Ensure these match what your deployment playbooks expect.
# =============================================================================

output "cluster_name" {
  description = "Name of the created RKE2 cluster"
  value       = var.cluster_name
}

output "node_ips" {
  description = "Public IP addresses of all RKE2 nodes"
  value = {
    for i, node in hcloud_server.rke2_nodes : "${var.cluster_name}-node-${i + 1}" => node.ipv4_address
  }
}

output "leader_node_ip" {
  description = "Public IP of the RKE2 leader node (node-1)"
  value       = hcloud_server.rke2_nodes[0].ipv4_address
}

output "domain_name" {
  description = "Root domain name"
  value       = var.domain_name
}

output "rancher_domain" {
  description = "Rancher domain name"
  value       = "rancher.${var.domain_name}"
}

output "kubeconfig_path" {
  description = "Absolute path to kubeconfig file"
  value       = abspath("${path.module}/output/kubeconfig.yaml")
}

output "dns_records" {
  description = "DNS A records created for the domain (round-robin when load balancer disabled)"
  value = var.enable_load_balancer ? [] : [
    for record in cloudflare_dns_record.rke2_nodes : {
      name  = record.name
      type  = record.type
      value = record.content
    }
  ]
}

output "load_balancer" {
  description = "Hetzner Load Balancer information (only when enable_load_balancer = true)"
  value = var.enable_load_balancer ? {
    name     = hcloud_load_balancer.rancher[0].name
    ipv4     = hcloud_load_balancer.rancher[0].ipv4
    ipv6     = hcloud_load_balancer.rancher[0].ipv6
    location = hcloud_load_balancer.rancher[0].location
  } : null
}

output "dns_record" {
  description = "Cloudflare DNS A record pointing to load balancer (only when enable_load_balancer = true)"
  value = var.enable_load_balancer ? {
    name  = cloudflare_dns_record.rancher[0].name
    type  = cloudflare_dns_record.rancher[0].type
    value = cloudflare_dns_record.rancher[0].content
    fqdn  = "${cloudflare_dns_record.rancher[0].name}.${var.domain_name}"
  } : null
}

output "ssh_access" {
  description = "SSH access information for cluster management"
  value = {
    leader_node = hcloud_server.rke2_nodes[0].ipv4_address
    user        = "root"
    key_path    = var.ssh_key_path
    example_cmd = "ssh -i ${var.ssh_key_path} root@${hcloud_server.rke2_nodes[0].ipv4_address}"
    note        = "Use this to access the cluster directly on the leader node"
  }
}

output "rancher_url" {
  description = "Rancher Server URL"
  value       = "https://rancher.${var.domain_name}"
}

output "rancher_bootstrap_password" {
  description = "Initial Rancher bootstrap password (save this securely!)"
  value       = random_password.rancher_bootstrap.result
  sensitive   = true
}

output "letsencrypt_email" {
  description = "Let's Encrypt email address"
  value       = var.letsencrypt_email
}

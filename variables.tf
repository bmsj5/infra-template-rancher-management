# =============================================================================
# Variables
# =============================================================================
# NOTE: Provider-specific variables are marked below.
# Adapt these for your cloud and DNS providers.
# =============================================================================

# -----------------------------------------------------------------------------
# Cloud Provider Credentials
# -----------------------------------------------------------------------------
# NOTE: Currently Hetzner Cloud - replace with your provider's token variable
variable "hcloud_token" {
  description = "Hetzner Cloud API token with read/write permissions"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# DNS Provider Credentials
# -----------------------------------------------------------------------------
# NOTE: Currently Cloudflare - replace with your DNS provider's token variable
variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions for the domain"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------
variable "domain_name" {
  description = "Root domain name in DNS provider (e.g., yourdomain.com) - DNS records will be created as rancher.yourdomain.com"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN"
  }
}

# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------
variable "cluster_name" {
  description = "Name of the RKE2 cluster"
  type        = string
  default     = "rancher-management-cluster"
}

variable "node_count" {
  description = "Number of RKE2 nodes to create (must be >= 3 for HA)"
  type        = number
  default     = 3
  validation {
    condition     = var.node_count >= 3
    error_message = "Node count must be at least 3 for HA RKE2 cluster"
  }
}

variable "rke2_version" {
  description = "RKE2 version to install (e.g., v1.34.2+rke2r1). See README for Rancher compatibility notes."
  type        = string
  default     = "v1.34.2+rke2r1"
  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+rke2r[0-9]+$", var.rke2_version))
    error_message = "RKE2 version must be in format vX.Y.Z+rke2rN (e.g., v1.34.2+rke2r1)"
  }
}

# -----------------------------------------------------------------------------
# Cloud Provider Configuration
# -----------------------------------------------------------------------------
# NOTE: Currently Hetzner Cloud - adapt for your provider
variable "region" {
  description = "Cloud provider region for the servers"
  type        = string
  default     = "fsn1"
  validation {
    condition = contains([
      "fsn1", "nbg1", "hel1", "ash", "hil"
    ], var.region)
    error_message = "Region must be one of: fsn1, nbg1, hel1, ash, hil"
  }
}

variable "server_type" {
  description = "Cloud provider server type"
  type        = string
  default     = "cx33"
  validation {
    condition = contains([
      "cx23", "cx33", "cx43", "cx53",
      "cpx22", "cpx32", "cpx42", "cpx52", "cpx62",
      "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63"
    ], var.server_type)
    error_message = "Server type must be one of: cx23, cx33, cx43, cx53, cpx22, cpx32, cpx42, cpx52, cpx62, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63"
  }
}

# -----------------------------------------------------------------------------
# SSH Configuration
# -----------------------------------------------------------------------------
variable "ssh_key_path" {
  description = "Path to the local SSH public key to upload to cloud provider"
  type        = string
  validation {
    condition     = fileexists(pathexpand(var.ssh_key_path))
    error_message = "SSH public key file must exist"
  }
}

# -----------------------------------------------------------------------------
# Application Configuration
# -----------------------------------------------------------------------------
variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt SSL certificate notifications"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.letsencrypt_email))
    error_message = "Let's Encrypt email must be a valid email address"
  }
}

# -----------------------------------------------------------------------------
# Load Balancer Configuration
# -----------------------------------------------------------------------------
variable "enable_load_balancer" {
  description = "Enable Hetzner Cloud Load Balancer for production-grade HA (recommended for production). If false, uses DNS round-robin."
  type        = bool
  default     = false
}

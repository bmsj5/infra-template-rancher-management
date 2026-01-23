# =============================================================================
# Provider Configuration
# =============================================================================
# NOTE: Currently configured for Hetzner Cloud + Cloudflare DNS.
# To use other providers, replace these provider blocks and update
# the corresponding resources in main.tf
# =============================================================================

terraform {
  required_providers {
    # Cloud Provider - currently Hetzner Cloud
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.59.0"
    }
    # DNS Provider - currently Cloudflare
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.16.0"
    }
    # Utility providers
    random = {
      source  = "hashicorp/random"
      version = "3.8.0"
    }
  }

  required_version = ">= 1.0"
}

# Cloud Provider - currently Hetzner Cloud
# Replace with your provider's configuration
provider "hcloud" {
  token = var.hcloud_token
}

# DNS Provider - currently Cloudflare
# Replace with your provider's configuration
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

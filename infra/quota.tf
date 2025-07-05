
# Defines quotas to enforce the Always Free tier limits for pay-as-go accounts.
# This ensures resource usage stays within free tier limits,
# preventing accidental charges.

resource "oci_limits_quota" "free_tier_quota" {
  # Required - The OCID of the compartment where the quota will be created.
  compartment_id = var.compartment_id

  # Required - The description of the quota.
  description = "Enforce Always Free tier compliance for all services."

  # Required - The name of the quota.
  name = "always-free-tier-quota"

  # Required - A list of quota statements.
  statements = [
    # Network Load Balancer - Always Free tier allows 1 micro load balancer
    "set load-balancer quota lb-10mbps-micro-count to 1 in tenancy",
    
    # Compute instances - Always Free tier allows 4 OCPUs and 24GB memory for A1 instances
    "set compute-memory quota standard-a1-memory-count to 24 in tenancy",
    "set compute-core quota standard-a1-core-count to 4 in tenancy",
    
    # Block Storage - Always Free tier allows 200GB total
    "set block-storage quota volume-count to 10 in tenancy",
    "set block-storage quota total-storage-gb to 200 in tenancy",
    
    # Object Storage - Always Free tier provides 20GB (enforced at service level)
    # Note: Object storage quotas are automatically limited by OCI for free tier
    
    # Database Service - Always Free tier allows limited database instances
    "set database quota vm-standard1-ocpu-count to 2 in tenancy",
    "set database quota vm-block-storage-gb to 100 in tenancy"
  ]
}

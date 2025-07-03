
# Defines a quota to enforce the Always Free tier limits for Network Load Balancers.
# This ensures that no more than one NLB can be created in the compartment,
# preventing accidental charges.

resource "oci_limits_quota" "nlb_quota" {
  # Required - The OCID of the compartment where the quota will be created.
  compartment_id = var.compartment_id

  # Required - The description of the quota.
  description = "Enforce Always Free tier compliance for Network Load Balancer."

  # Required - The name of the quota.
  name = "nlb-free-tier-quota"

  # Required - A list of quota statements.
  statements = [
    # This statement sets the limit for the 'load-balancer' family
    # to exactly 1 for the 10mbps-micro-count (Always Free tier) in the tenancy.
    "set load-balancer quota lb-10mbps-micro-count to 1 in tenancy"
  ]
}

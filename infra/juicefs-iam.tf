# Create a dedicated user for JuiceFS
resource "oci_identity_user" "juicefs_user" {
  compartment_id = var.compartment_id
  name           = "juicefs-service-user"
  description    = "Service user for JuiceFS Object Storage access"
  email          = var.letsencrypt_email # Reuse existing email variable
}

# Create Customer Secret Key for S3-compatible API access
resource "oci_identity_customer_secret_key" "juicefs_secret_key" {
  user_id      = oci_identity_user.juicefs_user.id
  display_name = "JuiceFS S3 Access Key"
}

# Create a group for JuiceFS users
resource "oci_identity_group" "juicefs_group" {
  compartment_id = var.compartment_id
  name           = "juicefs-users"
  description    = "Group for JuiceFS service users"
}

# Add the user to the group
resource "oci_identity_user_group_membership" "juicefs_user_group_membership" {
  group_id = oci_identity_group.juicefs_group.id
  user_id  = oci_identity_user.juicefs_user.id
}

# Create policy for JuiceFS Object Storage access
resource "oci_identity_policy" "juicefs_policy" {
  compartment_id = var.compartment_id
  name           = "juicefs-object-storage-policy"
  description    = "Policy for JuiceFS Object Storage access"
  
  statements = [
    "Allow group ${oci_identity_group.juicefs_group.name} to manage buckets in compartment id ${var.compartment_id}",
    "Allow group ${oci_identity_group.juicefs_group.name} to manage objects in compartment id ${var.compartment_id}",
    "Allow group ${oci_identity_group.juicefs_group.name} to read objectstorage-namespaces in compartment id ${var.compartment_id}"
  ]
}

# Note: Object Storage private endpoints must be created manually in OCI Console
# Navigate to: Networking > Customer connectivity > Private endpoint
# Create private endpoint for Object Storage service

# Create dedicated bucket for JuiceFS
resource "oci_objectstorage_bucket" "juicefs_bucket" {
  compartment_id = var.compartment_id
  name           = var.juicefs_bucket_name
  namespace      = data.oci_objectstorage_namespace.juicefs_namespace.namespace

  access_type           = "NoPublicAccess"
  object_events_enabled = false
  versioning           = "Disabled"
  
  depends_on = [oci_identity_policy.juicefs_policy]
}

data "oci_objectstorage_namespace" "juicefs_namespace" {
  compartment_id = var.compartment_id
}

output "juicefs_access_key" {
  value       = oci_identity_customer_secret_key.juicefs_secret_key.id
  description = "Access key for JuiceFS S3-compatible API"
}

# Private endpoint URL will be available after manual creation
# Format: https://<private-endpoint-guid>.objectstorage.<region>.oci.customer-oci.com
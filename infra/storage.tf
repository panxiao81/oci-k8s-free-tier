
data "oci_objectstorage_namespace" "ns" {}

resource "oci_objectstorage_bucket" "tfstate_bucket" {
  compartment_id = var.compartment_id
  name           = "oci-k8s-free-tier-tfstate"
  namespace      = data.oci_objectstorage_namespace.ns.namespace

  versioning = "Enabled"
}

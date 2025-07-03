terraform {
  backend "oci" {
    bucket = "oci-k8s-free-tier-tfstate"
    key    = "terraform.tfstate"
  }
}

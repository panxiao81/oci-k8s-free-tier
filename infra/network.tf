module "vcn" {
  source  = "oracle-terraform-modules/vcn/oci"
  version = "3.6.0"

  compartment_id = var.compartment_id
  region         = var.region

  vcn_name      = "k8s-vcn"
  vcn_dns_label = "k8s"
  vcn_cidrs     = ["10.0.0.0/16"]

  subnets = {
    private_subnet = {
        name = "k8s-private-subnet"
        cidr_block = "10.0.1.0/24"
        type = "private"
    }
    public_subnet = {
        name = "k8s-public-subnet"
        cidr_block = "10.0.0.0/24"
        type = "public"
    }
  }

  create_internet_gateway = true
  create_nat_gateway      = true
  create_service_gateway  = true
}

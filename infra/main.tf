data "oci_containerengine_cluster_option" "cluster_pod_network_options" {
  cluster_option_id = "all"
}

resource "oci_containerengine_cluster" "k8s_cluster" {
  compartment_id = var.compartment_id
  kubernetes_version = "v1.33.1"

  name = "k8s-cluster"
  vcn_id = module.vcn.vcn_id

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id = module.vcn.subnet_all_attributes.public_subnet.id
  }

  options {
    kubernetes_network_config {
      services_cidr = "10.96.0.0/16"
      pods_cidr = "10.244.0.0/16"
    }

    service_lb_subnet_ids = [module.vcn.subnet_all_attributes.public_subnet.id]
  }
  type = "ENHANCED_CLUSTER"
}

resource "oci_containerengine_node_pool" "k8s_node_pool" {
  cluster_id = oci_containerengine_cluster.k8s_cluster.id
  compartment_id = var.compartment_id
  kubernetes_version = oci_containerengine_cluster.k8s_cluster.kubernetes_version
  name = "k8s-node-pool"

  node_metadata = {
    user_data = base64encode(file("node-init.sh"))
  }

  node_shape = "VM.Standard.A1.Flex" # Always Free tier
  node_shape_config {
    memory_in_gbs = "12"
    ocpus = "2"
  }

  node_source_details {
    image_id = local.image_id
    source_type = "IMAGE"

    boot_volume_size_in_gbs = "50"
  }

  initial_node_labels {
    key = "name"
    value = "k8s-cluster"
  }

  node_config_details {
    node_pool_pod_network_option_details {
      cni_type = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [module.vcn.subnet_all_attributes.private_subnet.id]
    }

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id = module.vcn.subnet_all_attributes.private_subnet.id
    }

    size = 2
  }

  ssh_public_key = var.ssh_public_key
}

data "oci_containerengine_node_pool_option" "test_node_pool_option" {
  node_pool_option_id = "all"
  compartment_id = var.compartment_id
}

data "oci_containerengine_cluster_kube_config" "cluster_kube_config" {
  cluster_id = oci_containerengine_cluster.k8s_cluster.id
}

resource "local_file" "kube_config" {
  content  = data.oci_containerengine_cluster_kube_config.cluster_kube_config.content
  filename = "kubeconfig"
}

locals {
  // Get all recommended OKE images
  all_oke_images = data.oci_containerengine_node_pool_option.test_node_pool_option.sources

  // Get the cluster's k8s version string, e.g., "1.33"
  cluster_version_substring = substr(oci_containerengine_cluster.k8s_cluster.kubernetes_version, 1, 5)

  // Filter images that are for the correct k8s version
  compatible_images = [for img in local.all_oke_images : img if strcontains(img.source_name, local.cluster_version_substring) && strcontains(img.source_name, "aarch64")]

  // Sort the compatible images by name (descending) to get the latest one first
  sorted_compatible_images = reverse(sort([for img in local.compatible_images : img.source_name]))

  // Get the image_id of the latest image
  image_id = one([for img in local.compatible_images : img.image_id if img.source_name == local.sorted_compatible_images[0]])
}
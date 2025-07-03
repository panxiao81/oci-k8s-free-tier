output "cluster_name" {
  value = oci_containerengine_cluster.k8s_cluster.name
}

output "cluster_id" {
  value = oci_containerengine_cluster.k8s_cluster.id
}

output "cluster_endpoint" {
  value = oci_containerengine_cluster.k8s_cluster.endpoints[0].kubernetes
}

output "node_pool_name" {
  value = oci_containerengine_node_pool.k8s_node_pool.name
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.k8s_node_pool.id
}

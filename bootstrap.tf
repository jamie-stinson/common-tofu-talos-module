resource "talos_machine_secrets" "this" {
  talos_version = var.talos.cluster.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.talos.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = var.talos.cluster.compute.control_plane.nodes
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.talos.cluster.compute.control_plane.nodes[0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.talos.cluster.api_server_endpoint
}

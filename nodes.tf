resource "random_string" "this" {
  for_each = { for key, value in merge(var.talos.node_data.control_plane.nodes, var.talos.node_data.worker.nodes) : key => value }
  length   = 8
  lower    = true
  numeric  = true
  upper    = true
  special  = false
}

data "talos_machine_configuration" "this" {
  for_each           = { for key, value in merge(var.talos.node_data.control_plane.nodes, var.talos.node_data.worker.nodes) : key => value }
  cluster_name       = var.talos.cluster.name
  cluster_endpoint   = "https://${var.talos.cluster.vip_address}:6443"
  machine_type       = contains(keys(var.talos.node_data.control_plane.nodes), each.key) ? "controlplane" : "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.talos.cluster.kubernetes_version
  talos_version      = var.talos.cluster.talos_version
}

resource "talos_machine_configuration_apply" "this" {
  for_each                    = { for key, value in merge(var.talos.node_data.control_plane.nodes, var.talos.node_data.worker.nodes) : key => value }
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.key
  on_destroy                  = {
    graceful = false
    reboot   = false
    reset    = true
  }
  config_patches              = flatten([
    [
      templatefile("${path.module}/templates/install.yaml.tmpl", {
        hostname        = format("%s-%s", contains(keys(var.talos.node_data.control_plane.nodes), each.key) ? "controlplane" : "worker", random_string.this[each.key].result)
        dns_server      = var.talos.node_data.dns_endpoint
        ip_address      = each.key
        default_gateway = var.talos.node_data.default_gateway
        ntp_server      = var.talos.node_data.ntp_endpoint
      })
    ],
    # Add control plane only templates
    contains(keys(var.talos.node_data.control_plane.nodes), each.key) ? [
      templatefile("${path.module}/templates/vip.yaml.tmpl", {
        vip_address = var.talos.cluster.vip_address
      })
    ] : [],
    contains(keys(var.talos.node_data.control_plane.nodes), each.key) ? [
      templatefile("${path.module}/templates/metrics.yaml.tmpl", {
      })
    ] : []
  ])
}

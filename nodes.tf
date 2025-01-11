
data "talos_machine_configuration" "this" {
  for_each           = { for key, value in merge(var.talos.node_data.control_plane.nodes, var.talos.node_data.worker.nodes) : key => value }
  cluster_name       = var.talos.cluster.name
  cluster_endpoint   = "https://${var.talos.cluster.api_server}:6443"
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
    graceful = true
    reboot   = false
    reset    = false
  }
  config_patches              = flatten([
    [
      templatefile("${path.module}/templates/global.yaml.tmpl", {
        hostname             = format("%s-%s", contains(keys(var.talos.node_data.control_plane.nodes), each.key) ? "controlplane" : "worker", var.node_hostnames[each.key])
        primary_dns_server   = var.talos.node_data.primary_dns_server
        secondary_dns_server = var.talos.node_data.secondary_dns_server
        ip_address           = each.key
        default_gateway      = var.talos.node_data.default_gateway
        ntp_server           = var.talos.node_data.ntp_endpoint
        api_server           = var.talos.cluster.api_server
        subnet               = var.talos.node_data.subnet
        extra_mounts         = length(coalesce(var.talos.cluster.extra_mounts, {})) > 0 ? join("\n", [
  "    extraMounts:",
  join("\n", [
    for mount in var.talos.cluster.extra_mounts : 
    join("\n", [
      "      - destination: ${mount.path}",
      "        type: ${mount.type}",
      "        source: ${mount.path}",
      "        options:",
      join("\n", [for option in mount.options : "          - ${option}"])
    ])
  ])
]) : ""
      })
    ],
    # Control Plane only templates
    contains(keys(var.talos.node_data.control_plane.nodes), each.key) ? [
      templatefile("${path.module}/templates/controlPlane.yaml.tmpl", {
        api_server           = var.talos.cluster.api_server
        subnet               = var.talos.node_data.subnet
      }),
      templatefile("${path.module}/templates/podSecurityConfiguration.yaml.tmpl", {
      })
    ] : []
  ])
}

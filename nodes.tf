data "talos_machine_configuration" "this" {
  for_each = {
    for ip, node in merge(
      var.talos.cluster.compute.control_plane.nodes,
      var.talos.cluster.compute.worker.nodes
    ) : ip => node
  }

  cluster_name       = var.talos.cluster.name
  cluster_endpoint   = "https://${var.talos.cluster.api_server_endpoint}:6443"
  machine_type       = contains(keys(var.talos.cluster.compute.control_plane.nodes), each.key) ? "controlplane" : "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.talos.cluster.kubernetes_version
  talos_version      = var.talos.cluster.talos_version
}

resource "talos_machine_configuration_apply" "this" {
  for_each = {
    for ip, node in merge(
      var.talos.cluster.compute.control_plane.nodes,
      var.talos.cluster.compute.worker.nodes
    ) : ip => node
  }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.key

  on_destroy = {
    graceful = true
    reboot   = false
    reset    = false
  }

  config_patches = flatten([
    [
    # Control Plane & Worker Template
      templatefile("${path.module}/templates/global.yaml.tmpl", {
        hostname = format(
          "%s-%s",
          contains(keys(var.talos.cluster.compute.control_plane.nodes), each.key) ? "controlplane" : "worker",
          var.node_hostnames[each.key]
        )
        api_server_endpoint       = var.talos.cluster.api_server_endpoint
        extensions                = var.talos.cluster.extensions
        dns_servers               = var.talos.cluster.networking.dns_servers
        ntp_servers               = var.talos.cluster.networking.ntp_servers
        containerd_metrics_server = var.talos.cluster.monitoring.containerd_metrics_server
        install_disk              = var.talos.cluster.storage.install_disk
        encryption_type           = var.talos.cluster.storage.encryption_type
        extra_mounts              = var.talos.cluster.storage.extra_kubelet_mounts
        talos_version             = var.talos.cluster.talos_version
      })
    ],
    # Control Plane Template
    contains(keys(var.talos.cluster.compute.control_plane.nodes), each.key) ? [
      templatefile("${path.module}/templates/controlPlane.yaml.tmpl", {
        api_server_endpoint       = var.talos.cluster.api_server_endpoint
        cni                       = var.talos.cluster.networking.cni
        pod_subnets               = var.talos.cluster.networking.pod_subnets
        service_subnets           = var.talos.cluster.networking.service_subnets
        kubernetes_metrics_server = var.talos.cluster.monitoring.kubernetes_metrics_server
      }),
    # Disable Pod Security Admission
      templatefile("${path.module}/templates/podSecurityConfiguration.yaml.tmpl", {})
    ] : []
  ])
}

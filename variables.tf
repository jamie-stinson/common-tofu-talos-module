variable "talos" {
  description = "Talos configuration"
  type = object({
    cluster = object({
      name               = string
      vip_address        = string
      kubernetes_version = string
      talos_version      = string
    })
    node_data = object({
      default_gateway = string
      dns_endpoint    = string
      ntp_endpoint    = string
      control_plane   = object({
        nodes = map(object({}))
      })
      worker = object({
        nodes = map(object({}))
      })
    })
  })
}

variable "talos" {
  description = "Talos configuration"
  type = object({
    factory = object({
      url      = string
      platform = string
      arch     = string
    })
    cluster = object({
      name               = string
      api_server         = string
      kubernetes_version = string
      talos_version      = string
    })
    node_data = object({
      disk_size            = string
      node_name            = string
      subnet               = string
      default_gateway      = string
      dns_servers          = optional(list(string), [])
      ntp_endpoint         = string
      control_plane = object({
        cpu   = string
        memory = string
        nodes = map(object({}))
      })
      worker = object({
        cpu    = string
        memory = string
        nodes  = map(object({}))
      })
    })
  })
}

variable "node_hostnames" {
  type = map(string)
}

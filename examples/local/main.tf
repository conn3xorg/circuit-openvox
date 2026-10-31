variable "port" {
  type    = number
  default = 2317
}

module "openvox" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  manifest_path = local.manifest
  schedule      = "hourly"

  # Reading this from the step below makes the apply wait for the manifest,
  # and runs it again when the manifest changes.
  apply_trigger = conn3x_file.manifest__site["box"].sha256
}

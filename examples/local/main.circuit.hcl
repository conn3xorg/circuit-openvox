locals {
  manifest = "/etc/puppetlabs/code/site.pp"
}

# Puts a manifest on the host. Your own might come from git, a package or
# rsync: the circuit only needs it at manifest_path before the apply.
circuit "manifest" {
  hosts = { box = "127.0.0.1" }

  ssh {
    user             = "root"
    port             = var.port
    private_key_file = "./id_ed25519"
    known_hosts_file = "./known_hosts"
  }

  step "dirs" {
    for_each = toset(["/etc/puppetlabs", "/etc/puppetlabs/code"])
    directory {
      path = item.value
    }
  }

  step "site" {
    file {
      path    = local.manifest
      content = <<-EOT
        file { '/etc/hello-from-openvox':
          ensure  => file,
          content => "Applied by OpenVox in local mode.\n",
          mode    => '0644',
        }
      EOT
    }
  }
}

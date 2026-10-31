# Facts give each host's distribution and architecture, which pick the package.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = contains(keys(var.checksums), "${contains(["rocky", "almalinux", "rhel"], self.os_id) ? "el/${split(".", self.os_version)[0]}" : "${self.os_id}/${self.os_version}"}/${self.arch}")
      error_message = "Host ${each.key} runs ${self.os_id} ${self.os_version} on ${self.arch}. This circuit has OpenVox packages for ${join(", ", sort(keys(var.checksums)))}."
    }
  }
}

locals {
  # OpenVox publishes one build per Enterprise Linux major version, under "el".
  # Fedora's os_family is also redhat, so this can't go by family.
  platform = { for name, f in data.conn3x_host.facts : name => contains(["rocky", "almalinux", "rhel"], f.os_id) ? "el/${split(".", f.os_version)[0]}" : "${f.os_id}/${f.os_version}" }

  deb_arch   = { x86_64 = "amd64", aarch64 = "arm64" }
  collection = "openvox${split(".", var.openvox_version)[0]}"

  package = { for name, f in data.conn3x_host.facts : name => f.os_family == "debian" ?
    "openvox-agent_${var.openvox_version}-1+${f.os_id}${f.os_version}_${local.deb_arch[f.arch]}.deb" :
    "openvox-agent-${var.openvox_version}-1.el${split(".", f.os_version)[0]}.${f.arch}.rpm"
  }

  url = { for name, f in data.conn3x_host.facts : name => f.os_family == "debian" ?
    "https://apt.voxpupuli.org/pool/${local.collection}/o/openvox-agent/${local.package[name]}" :
    "https://yum.voxpupuli.org/${local.collection}/el/${split(".", f.os_version)[0]}/${f.arch}/${local.package[name]}"
  }

  cache_dir = "/var/cache/conn3x-openvox"
  puppet    = "/opt/puppetlabs/bin/puppet"
  unit_path = "/etc/systemd/system/openvox-apply"
  applies   = var.manifest_path != null

  # Without --detailed-exitcodes, a run where a resource failed still exits 0.
  # With it, 2 means "changed something" and only 4 and 6 mean failure.
  service_content = <<-EOT
    # Written by Conn3x. Changes here are overwritten on the next apply.
    [Unit]
    Description=Apply OpenVox manifests in local mode
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=oneshot
    Environment=HOME=/root
    SuccessExitStatus=2
    ExecStart=${local.puppet} apply --detailed-exitcodes${var.module_path != null ? " --modulepath ${var.module_path}" : ""} ${coalesce(var.manifest_path, "-")}
  EOT

  timer_content = <<-EOT
    # Written by Conn3x. Changes here are overwritten on the next apply.
    [Unit]
    Description=Apply OpenVox manifests on a schedule

    [Timer]
    OnCalendar=${coalesce(var.schedule, "hourly")}
    # A run missed while the host was off happens when it comes back.
    Persistent=true

    [Install]
    WantedBy=timers.target
  EOT
}

circuit "openvox" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # findutils and tar are what the package depends on, and dpkg and rpm won't
  # fetch them. The minimal images leave some of these out.
  step "packages" {
    for_each = toset(["curl", "findutils", "tar"])
    package {
      name = item.value
    }
  }

  step "cache_dir" {
    directory {
      path = local.cache_dir
    }
  }

  step "download" {
    download {
      url    = local.url[each.key]
      sha256 = var.checksums["${local.platform[each.key]}/${data.conn3x_host.facts[each.key].arch}"]
      dest   = "${local.cache_dir}/${local.package[each.key]}"
    }
  }

  # Goes straight to dpkg and rpm, so no repository of OpenVox's stays on the
  # host to move the agent past openvox_version, and --oldpackage lets
  # openvox_version go down as well as up.
  step "install" {
    command {
      command = data.conn3x_host.facts[each.key].os_family == "debian" ? "dpkg -i ${local.cache_dir}/${local.package[each.key]}" : "rpm -U --oldpackage ${local.cache_dir}/${local.package[each.key]}"
      unless  = data.conn3x_host.facts[each.key].os_family == "debian" ? "[ \"$(dpkg-query -W -f '$${Version}' openvox-agent 2>/dev/null | cut -d- -f1)\" = ${var.openvox_version} ]" : "[ \"$(rpm -q --qf '%%{VERSION}' openvox-agent 2>/dev/null)\" = ${var.openvox_version} ]"
    }
  }

  # The package's own unit runs the agent against a server, and dpkg enables
  # it, so without this the host would look for a server called "puppet" from
  # its next boot.
  step "agent_off" {
    service {
      name    = "puppet.service"
      state   = "stopped"
      enabled = false
    }
  }

  step "service" {
    for_each = local.applies ? toset(["service"]) : toset([])
    file {
      path      = "${local.unit_path}.service"
      content   = local.service_content
      on_remove = "delete"
    }
  }

  step "timer_file" {
    for_each = var.schedule != null ? toset(["timer"]) : toset([])
    file {
      path      = "${local.unit_path}.timer"
      content   = local.timer_content
      on_remove = "delete"
    }
  }

  step "reload" {
    command {
      command = "systemctl daemon-reload"
      triggers = {
        service = local.applies ? sha256(local.service_content) : ""
        timer   = var.schedule != null ? sha256(local.timer_content) : ""
      }
    }
  }

  step "timer" {
    for_each = var.schedule != null ? toset(["timer"]) : toset([])
    service {
      name      = "openvox-apply.timer"
      state     = "started"
      enabled   = true
      on_remove = "delete"
    }
  }

  # systemctl waits for a oneshot unit to finish and fails if it fails, so a
  # failed run fails the apply, with the detail in the journal.
  step "apply" {
    for_each = local.applies ? toset(["apply"]) : toset([])
    command {
      command = "systemctl start openvox-apply.service"
      triggers = {
        version = var.openvox_version
        service = sha256(local.service_content)
        trigger = var.apply_trigger
      }
    }
  }
}

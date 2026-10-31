variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "openvox_version" {
  type        = string
  default     = "9.2.1"
  description = "openvox-agent release to install, from https://github.com/OpenVoxProject/openvox/releases. Change it with checksums."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.openvox_version))
    error_message = "openvox_version is a version such as \"9.2.1\"."
  }
}

variable "checksums" {
  type        = map(string)
  description = "SHA-256 of the package for each platform, by \"PLATFORM/VERSION/ARCH\". Change these with openvox_version."
  default = {
    "ubuntu/24.04/x86_64"  = "83225030da8f2c94a649318f7f02ca9ddc01919446ae5ec04dcb1e9d1343f58e"
    "ubuntu/24.04/aarch64" = "1f600b2b194ad4fb199b13228fdfbfe29dde1e5e0b2dfba42b578c06c6b6a907"
    "debian/13/x86_64"     = "352e3cdc724579d62c059e9f76dc6e6f3067516de1428bea178d57a27cfc7280"
    "debian/13/aarch64"    = "42edff78021628009976aba513dd1158979610d4a3a6fe972c1ae55d6903d056"
    "el/10/x86_64"         = "c55617f8c34f482e373b9037456879063c5cfafa9c3f18b7372d6bd23af129ca"
    "el/10/aarch64"        = "d5ca6be65f2043b28bbe7bb8f1621c461250554e35a36165c8319c265f5933fb"
  }

  validation {
    condition     = alltrue([for k, c in var.checksums : can(regex("^(ubuntu|debian|el)/[0-9.]+/(x86_64|aarch64)$", k)) && can(regex("^[0-9a-f]{64}$", c))])
    error_message = "checksums maps a key such as \"debian/13/x86_64\" to a SHA-256 in lowercase hex."
  }
}

variable "manifest_path" {
  type        = string
  default     = null
  description = "Manifest file, or directory of manifests, on the host to apply. Whatever can write here can run anything as root, so keep it writable by root alone. When null, the circuit only installs the agent."

  validation {
    condition     = var.manifest_path == null || can(regex("^/[a-zA-Z0-9/_.-]*[^/]$", coalesce(var.manifest_path, "-")))
    error_message = "manifest_path must be an absolute path without a trailing slash."
  }
}

variable "module_path" {
  type        = string
  default     = null
  description = "Directories on the host to look for modules in, separated by colons. When null, OpenVox's own default, under /etc/puppetlabs/code."

  validation {
    condition     = var.module_path == null || can(regex("^/[a-zA-Z0-9/_.:-]*$", coalesce(var.module_path, "-")))
    error_message = "module_path must be absolute paths separated by colons."
  }
}

variable "schedule" {
  type        = string
  default     = null
  description = "systemd OnCalendar expression that applies on a timer, such as \"hourly\" or \"*:0/30\". When null, there is no timer."

  validation {
    condition     = var.schedule == null || (can(regex("^[a-zA-Z0-9 *:/.,~-]+$", coalesce(var.schedule, "-"))) && var.manifest_path != null)
    error_message = "schedule is an OnCalendar expression, such as \"hourly\", and needs a manifest_path to run."
  }
}

variable "apply_trigger" {
  type        = string
  default     = ""
  description = "Any string, such as a manifest's hash or a Git commit. Changing it applies on the next conn3x apply, for when something the circuit can't see has changed."
}

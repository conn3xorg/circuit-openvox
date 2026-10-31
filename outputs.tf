output "service" {
  description = "systemd unit that runs one apply. Start it by hand with systemctl start, and read its log with journalctl -u."
  value       = "openvox-apply.service"
}

output "puppet" {
  description = "Path of the agent's command on each host."
  value       = local.puppet
}

#!/usr/bin/env sh
# Run this on the host, as root, after an apply: it shows the manifest made its
# file, that a run puts the file back when it's gone, and that the run after
# that changes nothing. --detailed-exitcodes makes puppet exit 2 when it
# changed something and 0 when it didn't, which systemd records for the unit.
set -eu
status() { systemctl show openvox-apply.service -p ExecMainStatus --value; }

grep -q 'Applied by OpenVox' /etc/hello-from-openvox
echo "file: present"
[ "$(systemctl is-enabled openvox-apply.timer)" = enabled ]
[ "$(systemctl is-active openvox-apply.timer)" = active ]
echo "timer: on"

# There's no server, so the package's agent service stays off, even on boot.
if systemctl is-active puppet.service >/dev/null || systemctl is-enabled puppet.service >/dev/null; then
  echo "The package's agent service is on, and it shouldn't be." >&2
  exit 1
fi
echo "agent service: off"

rm /etc/hello-from-openvox
systemctl start openvox-apply.service
[ "$(status)" = 2 ] || { echo "Expected the first run to change something, got exit $(status)" >&2; exit 1; }
grep -q 'Applied by OpenVox' /etc/hello-from-openvox
echo "first run: put the file back (exit 2)"

systemctl start openvox-apply.service
[ "$(status)" = 0 ] || { echo "Expected the second run to change nothing, got exit $(status)" >&2; exit 1; }
echo "second run: nothing to do (exit 0)"

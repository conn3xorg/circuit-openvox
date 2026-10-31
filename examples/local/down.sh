#!/usr/bin/env sh
# Stops the container, which removes it and its volumes since up.sh started it
# with --rm, and deletes everything up.sh and Conn3x created here.
set -eu
cd "$(dirname "$0")"
${PODMAN:-podman} stop -i "${NAME:-circuit-openvox}" >/dev/null 2>&1 || true
rm -rf id_ed25519 id_ed25519.pub known_hosts .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
echo "Removed."

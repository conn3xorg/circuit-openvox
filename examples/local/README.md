# Local example

Applies circuit-openvox to a throwaway Rocky Linux 10 container with systemd. You need Conn3x and Podman.

It writes a small manifest to `/etc/puppetlabs/code/site.pp`, installs the OpenVox agent, applies the manifest once, and sets an hourly timer:

```sh
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` To see the idempotence for yourself, run [check.sh](check.sh) on the host:

```sh
ssh -p 2317 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 sh -s < check.sh
```

It deletes the file and runs the service twice. The first run puts the file back and exits 2, which is how `--detailed-exitcodes` says something changed. The second finds nothing to do and exits 0.

Change the manifest in `main.circuit.hcl` and apply again, and Conn3x runs it again, because the example's `apply_trigger` reads the file's hash.

`up.sh` listens on `127.0.0.1:2317`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` stops the container, which removes it since it started with `--rm`, and deletes the key and the state.

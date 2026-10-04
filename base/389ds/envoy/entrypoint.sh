#!/bin/sh
# Entrypoint for the Envoy container. Envoy reads its certificate through SDS
# from /etc/envoy/sds/server.yaml. This script renders that file from the
# 389ds-tls Secret mount (/etc/envoy/tls), keeps it current in the background,
# and then execs Envoy.
#
# The Secret is updated by kubelet with a symlink swap, so the files are polled
# by content hash. The SDS file is replaced by rename so Envoy's watcher sees
# the change.
set -eu

in=/etc/envoy/tls
out=/etc/envoy/sds
last=""

render() {
  cur=$(cat "$in/server.crt" "$in/server.key" 2>/dev/null | sha256sum | cut -d' ' -f1 || true)
  if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
    {
      printf 'resources:\n'
      printf '  - "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret\n'
      printf '    name: server\n'
      printf '    tls_certificate:\n'
      printf '      certificate_chain:\n'
      printf '        filename: %s\n' "$in/server.crt"
      printf '      private_key:\n'
      printf '        filename: %s\n' "$in/server.key"
    } >"$out/server.yaml.tmp"
    mv -f "$out/server.yaml.tmp" "$out/server.yaml"
    last="$cur"
    echo "rendered certificate $cur"
  fi
}

# Render before Envoy starts so the SDS file exists when Envoy loads its config.
render

# The subshell inherits $last, so an unchanged certificate is not rewritten.
(
  while true; do
    sleep 5
    render
  done
) &

exec envoy -c /etc/envoy/envoy.yaml

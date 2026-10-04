#!/bin/sh
# Entrypoint for the Envoy container. Envoy reads its certificate through SDS
# from /etc/envoy/sds/server.yaml. This script keeps that file current from the
# 389ds-tls Secret mount (/etc/envoy/tls) and then execs Envoy.
#
# The Secret is updated by kubelet with a symlink swap, so the files are polled
# by content hash. Envoy reads the certificate and key separately, so the pair is
# copied into a versioned directory under /etc/envoy/sds first. Envoy then never
# reads files that kubelet can swap underneath it. The SDS file is replaced by
# rename so Envoy's watcher sees the change.
set -eu

in=/etc/envoy/tls
out=/etc/envoy/sds
last=""
previous=""

hash_pair() {
  cat "$1/server.crt" "$1/server.key" 2>/dev/null | sha256sum | cut -d' ' -f1
}

render() {
  before=$(hash_pair "$in" || true)
  if [ -z "$before" ] || [ "$before" = "$last" ]; then
    return 0
  fi

  # Copy the pair, then confirm the source did not change during the copy and
  # that the copy matches it.
  new=$(mktemp -d "$out/.new.XXXXXX")
  cp "$in/server.crt" "$in/server.key" "$new/"
  after=$(hash_pair "$in" || true)
  if [ "$before" != "$after" ] || [ "$(hash_pair "$new")" != "$before" ]; then
    rm -rf "$new"
    echo "certificate changed while copying; retrying"
    return 0
  fi

  dir="$out/$before"
  rm -rf "$dir"
  mv "$new" "$dir"

  {
    printf 'resources:\n'
    printf '  - "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret\n'
    printf '    name: server\n'
    printf '    tls_certificate:\n'
    printf '      certificate_chain:\n'
    printf '        filename: %s\n' "$dir/server.crt"
    printf '      private_key:\n'
    printf '        filename: %s\n' "$dir/server.key"
  } >"$out/server.yaml.tmp"
  mv -f "$out/server.yaml.tmp" "$out/server.yaml"

  # Keep the previous version until the next render in case Envoy is still
  # reading it; remove anything older.
  previous=$last
  last=$before
  for d in "$out"/*; do
    [ -d "$d" ] || continue
    case "$d" in
      "$dir"|"$out/$previous") ;;
      *) rm -rf "$d" ;;
    esac
  done
  echo "rendered certificate $before"
}

# Render before Envoy starts so the SDS file exists when Envoy loads its config.
render

# The subshell inherits $last and $previous, so an unchanged certificate is not
# rewritten.
(
  while true; do
    sleep 5
    render
  done
) &

exec envoy -c /etc/envoy/envoy.yaml

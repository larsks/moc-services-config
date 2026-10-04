#!/bin/bash
# Container entrypoint for 389ds. Starts the server, applies every LDIF file in
# /ldif-init over the local ldapi socket, and keeps the server running in the
# foreground until it receives SIGTERM.
#
# The LDIF files are applied on every start. Replace-style changes are safe to
# repeat, and "-a -c" lets add records for existing entries fail without stopping
# the rest of the import.
set -eu

dsc=/usr/lib/dirsrv/dscontainer
ldapi="ldapi://%2Fdata%2Frun%2Fslapd-localhost.socket"

"$dsc" -r &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true' TERM INT

# Wait until the server answers.
i=0
until "$dsc" -H >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "ERROR: 389ds did not become healthy" >&2
    kill -TERM "$pid" 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

for f in /ldif-init/*.ldif; do
  [ -f "$f" ] || continue
  echo "applying $f"
  ldapmodify -Y EXTERNAL -H "$ldapi" -a -c -f "$f" || echo "errors applying $f" >&2
done

wait "$pid"

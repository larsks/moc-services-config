#!/bin/bash
# Container entrypoint for dirsrv. Starts the server, applies every LDIF file in
# /ldif-init over the local ldapi socket, and keeps the server running in the
# foreground until it receives SIGTERM.
#
# The LDIF files are applied on every start. Replace-style changes are safe to
# repeat, and "-a -c" lets add records for existing entries fail without stopping
# the rest of the import.
#
# FIPS mode is a property of the NSS security database, not a cn=config
# attribute, so it can't be set via LDIF. When FIPS_ENABLED=1 we enable it with
# modutil and restart the server so it takes effect.
set -eu

# dscontainer lives in /usr/lib in 389ds and /usr/libexec in rhds
for try in /usr/lib/dirsrv/dscontainer /usr/libexec/dirsrv/dscontainer; do
  if [ -x "$try" ]; then
    dsc=$try
    break
  fi
done

if [ -z "$dsc" ]; then
  echo "ERROR: unable to find dscontainer" >&2
  exit 1
fi

ldapi="$LDAPI_SOCKET"
dbdir="/etc/dirsrv/slapd-localhost"

start_server() {
  "$dsc" -r &
  pid=$!
}

# Wait until the server answers. This queries the server directly rather than
# using "dscontainer -H": running -H while the server is still starting launches
# a second instance, which stops the first one.
wait_healthy() {
  i=0
  until ldapsearch -Y EXTERNAL -H "$ldapi" -b "" -s base >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
      echo "ERROR: dirsrv did not become healthy" >&2
      kill -TERM "$pid" 2>/dev/null || true
      exit 1
    fi
    sleep 1
  done
}

start_server
trap 'kill -TERM "$pid" 2>/dev/null || true' TERM INT
wait_healthy

if [ "${FIPS_ENABLED:-0}" = "1" ] && ! modutil -dbdir "$dbdir" -chkfips true 2>/dev/null | grep -q "FIPS mode enabled"; then
  echo "enabling FIPS mode"
  modutil -dbdir "$dbdir" -fips true -force
  kill -TERM "$pid"
  wait "$pid" || true
  start_server
  wait_healthy
fi

for f in /ldif-init/*.ldif; do
  [ -f "$f" ] || continue
  echo "applying $f"
  ldapmodify -Y EXTERNAL -H "$ldapi" -a -c -f "$f" || echo "errors applying $f" >&2
done

wait "$pid"

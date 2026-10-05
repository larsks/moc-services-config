#!/bin/bash

while getopts e ch; do
  case $ch in
  e) create_envrc=1 ;;
  *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))

ARGOCD_PASSWORD=$(oc -n argocd extract secret/argocd-initial-admin-secret --to=- 2>/dev/null)
KEYCLOAK_PASSWORD=$(oc -n keycloak extract secret/keycloak-initial-admin --keys=password --to=- 2>/dev/null)
LLDAP_PASSWORD=$(oc -n keycloak extract secret/lldap-credentials --keys=LLDAP_LDAP_USER_PASS --to=- 2>/dev/null)
DS_DM_PASSWORD=$(oc -n dirsrv extract secret/dirsrv-credentials --to=- 2>/dev/null)
SSSD_BIND_PASSWORD=$(oc -n dirsrv extract secret/sssd-bind-credentials --to=- 2>/dev/null)

cat <<EOF
ArgoCD:
  URL: http://localhost:7080/argocd/
  Username: admin
  Password: $ARGOCD_PASSWORD
Keycloak:
  URL: http://localhost:7080/keycloak/
  Username: temp-admin
  Password: $KEYCLOAK_PASSWORD
LLDAP:
  URL: http://localhost:7080/lldap/
  Username: admin
  Password: $LLDAP_PASSWORD
dirsrv:
  Username: cn=Directory Manager
  Password: $DS_DM_PASSWORD
sssd-bind:
  Username: uid=sssd-bind,ou=services,dc=massopen,dc=cloud
  Password: $SSSD_BIND_PASSWORD
EOF

if ((create_envrc)); then
  cat >.envrc <<EOF
export LDAPTLS_REQCERT=never
export TF_VAR_ldap_bind_password=$DS_DM_PASSWORD
export KEYCLOAK_USER=temp-admin
export KEYCLOAK_PASSWORD=$KEYCLOAK_PASSWORD
export LLDAP_PASSWORD=$LLDAP_PASSWORD
export DS_DM_PASSWORD=$DS_DM_PASSWORD
export TF_VAR_sssd_bind_password=$SSSD_BIND_PASSWORD
EOF
fi

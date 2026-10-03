#!/bin/sh

ARGOCD_PASSWORD=$(oc -n argocd extract secret/argocd-initial-admin-secret --to=- 2>/dev/null)
KEYCLOAK_PASSWORD=$(oc -n keycloak extract secret/keycloak-initial-admin --keys=password --to=- 2>/dev/null)
LLDAP_PASSWORD=$(oc -n keycloak extract secret/lldap-credentials --keys=LLDAP_LDAP_USER_PASS --to=- 2>/dev/null)
DS389_PASSWORD=$(oc -n 389ds extract secret/389ds-credentials --to=- 2>/dev/null)

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
389ds:
  Username: cn=Directory Manager
  Password: $DS389_PASSWORD
EOF

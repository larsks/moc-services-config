#!/bin/bash

ARGOCD_PASSWORD=$(oc -n argocd extract secret/argocd-initial-admin-secret --to=- 2>/dev/null)
KEYCLOAK_PASSWORD=$(oc -n keycloak extract secret/keycloak-initial-admin --keys=password --to=- 2>/dev/null)

cat <<EOF
ArgoCD:
  Username: admin
  Password: $ARGOCD_PASSWORD
Keycloak:
  URL: https://localhost:7443/
  Username: temp-admin
  Password: $KEYCLOAK_PASSWORD
EOF

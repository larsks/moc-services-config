#!/bin/bash

log() {
  printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

rand_suffix=$(
  tr -dc 'a-z0-9' </dev/urandom | head -c 6
  echo
)

kind --help >&/dev/null || die "missing kind; see https://kind.sigs.k8s.io/"
oc --help >&/dev/null || die "missing oc; see https://kubernetes.io/docs/tasks/tools/"

if kind get clusters -q | grep -q moc-services; then
  log "deleting existing moc-services cluster"
  rm -f kubeconfig-*
  kind get clusters | grep moc-services | xargs -n1 kind delete cluster --name
fi

if [ -f tofu/terraform.tfstate ]; then
  log "deleting old tofu state"
  rm -f tofu/terraform.tfstate*
fi

log "creating cluster"
kind create cluster --config cluster.yaml --name "moc-services-$rand_suffix" --kubeconfig "kubeconfig-$rand_suffix"
export KUBECONFIG="kubeconfig-$rand_suffix"
log "kubeconfig: $KUBECONFIG"

log "installing argocd"
oc apply -k overlays/kind/argocd --server-side >/dev/null

log "waiting for argocd to become ready"
oc wait --for condition=Available --timeout=5m -n argocd deploy/argocd-server deploy/argocd-repo-server ||
  die "failed waiting for argocd"

log "applying applicationsets"
oc apply -k overlays/kind/applicationsets --server-side >/dev/null

oc config set-context --current --namespace=argocd
for app in applicationsets argocd cert-manager external-secrets haproxy-ingress pgo keycloak dirsrv; do
  log "waiting for $app to exist..."
  timeout 60 sh -c 'until oc get application -n argocd "$1" >&/dev/null; do sleep 1; done' -- "$app" ||
    die "application $app was never created"

  log "waiting for $app to sync..."
  oc wait --for=jsonpath='{.status.sync.status}'=Synced --timeout=600s -n argocd "application/$app" >/dev/null ||
    die "timed out waiting for $app to sync"

  log "waiting for $app to be healthy..."
  oc wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=600s -n argocd "application/$app" >/dev/null ||
    die "timed out waiting for $app to become healthy"
done

log "all done."

bash extract-credentials.sh

#!/bin/bash

rand_suffix=$(
  tr -dc 'a-z0-9' </dev/urandom | head -c 6
  echo
)

echo "deleting older cluster"
rm -f kubeconfig-*
kind get clusters | grep moc-services | xargs --no-run-if-empty -n1 kind delete cluster --name

echo "creating cluster"
kind create cluster --config cluster.yaml --name "moc-services-$rand_suffix" --kubeconfig "kubeconfig-$rand_suffix"
export KUBECONFIG="kubeconfig-$rand_suffix"
echo "kubeconfig: $KUBECONFIG"

echo "installing argocd"
oc apply -k overlays/kind/argocd --server-side

echo "waiting for argocd to become ready"
oc wait --for condition=Available --timeout=5m -n argocd deploy/argocd-server deploy/argocd-repo-server

echo "applying applicationsets"
oc apply -k overlays/kind/applicationsets --server-side

echo "waiting for keycloak namespace"
until oc get ns keycloak >&/dev/null; do sleep 1; done

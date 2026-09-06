# MOC Keycloak IDP

Deploy Keycloak and LLDAP, backed by Postgres.

## Contents

This repository will deploy:

- ArgoCD
- Crunchy Data [PGO]
- [Keycloak operator]
- [LLDAP]
- [Cert-manager]
- [External secrets]

[keycloak operator]: https://www.keycloak.org/guides#operator
[PGO]: https://github.com/crunchydata/postgres-operator
[lldap]: https://github.com/lldap/lldap
[Cert-manager]: https://cert-manager.io/
[external secrets]: https://external-secrets.io/

Everything is managed with ArgoCD.

## Repository layout

- `base` contains most of the deployment manifests
- `overlays` contains environment-specific overlays.
- `overlays/kind` generates the configuration used when deploying into KinD.
- `overlays/aws` generates our production configuration.
- `overlays/*/applicationsets` generates the applicationsets that manage everything else through ArgoCD.

### Base

```
base
├── applicationsets
│   └── root.yaml
├── argocd
│   ├── components
│   │   ├── enable-helm
│   │   └── healthchecks
│   ├── ha
│   ├── nonha
│   └── shared
│       └── namespace.yaml
├── cert-manager
│   ├── config
│   │   └── selfsigned.yaml
│   └── operator
├── external-secrets
│   ├── config
│   │   └── password-generator.yaml
│   └── operator
│       └── namespace.yaml
├── haproxy-ingress
│   └── namespace.yaml
├── keycloak
│   ├── config
│   │   ├── keycloak-tls-certificate.yaml
│   │   ├── keycloak.yaml
│   │   └── postgrescluster.yaml
│   ├── lldap
│   │   ├── deployment.yaml
│   │   ├── files
│   │   │   └── userschema.json
│   │   └── service.yaml
│   └── operator
│       └── namespace.yaml
└── pgo
    └── namespace.yaml
```

### Overlays

```
overlays
├── aws
│   ├── applicationsets
│   ├── argocd
│   ├── cert-manager
│   ├── external-secrets
│   ├── keycloak
│   └── pgo
└── kind
    ├── applicationsets
    ├── argocd
    ├── cert-manager
    ├── external-secrets
    ├── haproxy-ingress
    ├── keycloak
    │   └── config
    │       ├── lldap-credentials.yaml
    │       └── lldap-ingress.yaml
    └── pgo
```

## Theory of Operation

After deploying ArgoCD, we apply the `root` [ApplicationSet]. An ApplicationSet is a template for creating one or more ArgoCD applications. In this case, we are using the [git generator] to create applications for each directory in the per-environment overlay. For example, if `overlays/kind` contains:

[applicationset]: https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/
[git generator]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/

```
applicationsets
argocd
cert-manager
external-secrets
haproxy-ingress
keycloak
pgo
```

Then the `root` ApplicationSet will create:

```
$ argo app list -o name
argocd/applicationsets
argocd/argocd
argocd/cert-manager
argocd/external-secrets
argocd/haproxy-ingress
argocd/keycloak
argocd/pgo
```

This repository makes extensive use of ArgoCD [sync waves] to sequence the installation of dependent resources. In general, all CRDs and operators install at sync-wave 0, while CRs install at sync wave 1. Sync waves are managed by annotations on resources, and in most cases are set in the appropriate `kustomization.yaml` file.

[sync waves]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/#how-sync-waves-work

## Testing in KinD

To apply this repository to a fresh [KinD] environment:

```
oc apply -k overlays/kind/argocd --server-side &&
oc wait --for condition=Available --timeout=5m -n argocd deploy/argocd-server deploy/argocd-repo-server &&
oc apply -k overlays/kind/applicationsets --server-side
```

It will take several minutes for everything to become ready.

[kind]: https://kind.sigs.k8s.io/

### Credentials

#### ArgoCD

To authenticate the argocd CLI to argocd:

```
ARGOCD_PASSWORD=$(oc -n argocd extract secret/argocd-initial-admin-secret --to=-)
argocd --port-forward --port-forward-namespace=argocd login --username admin --password "$ARGOCD_PASSWORD"
```

You'll probably want an alias:

```
alias apf='argocd --port-forward --port-forward-namespace=argocd'
```

Then you can run argocd command like this:

- `apf app list`
- `apf app get keycloak`
- Etc.

#### Keycloak

```
oc -n keycloak extract secret/keycloak-initial-admin --keys=password --to=-
```

### LLDAP

```
oc -n keycloak extract secret/lldap-credentials --keys=LLDAP_LDAP_USER_PASS --to=-
```

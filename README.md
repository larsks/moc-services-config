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
- `overlays/kind` generates the configuration used when deploying into
  KinD.
- `overlays/aws` generates our production configuration.
- `overlays/*/applicationsets` generates the applicationsets that manage
  everything else through ArgoCD.

## Theory of Operation

After deploying ArgoCD, we apply the `root` [ApplicationSet]. An
ApplicationSet is a template for creating one or more ArgoCD applications.
In this case, we are using the [git generator] to create applications for
each directory in the per-environment overlay. For example, if
`overlays/kind` contains:

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
$ argocd app list -o name
argocd/applicationsets
argocd/argocd
argocd/cert-manager
argocd/external-secrets
argocd/haproxy-ingress
argocd/keycloak
argocd/pgo
```

This repository makes use of ArgoCD [sync waves] to sequence the
installation of dependent resources. In general, all CRDs and operators
install at sync-wave 0, while CRs install at sync wave 1. Sync waves are
managed by annotations on resources, and in most cases are set in the
appropriate `kustomization.yaml` file.

[sync waves]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/#how-sync-waves-work

## Testing in KinD

To apply this repository to a fresh [KinD] environment:

[kind]: https://kind.sigs.k8s.io/

```
sh run-in-kind.sh
```

It will take several minutes for everything to become ready. The script will produce a `kubeconfig-<suffix>` file in your current directory; you can point your client at it either by using the `--kubeconfig` option:

```sh
oc --kubeconfig kubeconfig-<suffix> ...
```

Or by setting the `KUBECONFIG` environment variable:

```sh
export KUBECONFIG=$PWD/kubeconfig-<suffix>
```

The latter is generally safer (you won't forget to add `--kubeconfig` and accidentally operate on the wrong cluster).

### Services

Run `extract-credentials.sh` to output service URLs, usernames, and
passwords on the console.

#### ArgoCD

URL: <http://localhost:7080/argocd/>

If you want to use the `argocd` cli, you have two options. When given the
`--core` option, `argocd` will operate using only Kubernetes APIs. This is
generally sufficient and means you don't need to authenticate explicitly to
ArgoCD:

```sh
argocd --core app list
```

For `--core` to work, your current namespace must be set to the `argocd`
namespace:

```sh
oc config set-context --current --namespace=argocd
```

There may be some features that require directly communicating with the
ArgoCD API (or you may get tired of having to switch back to the `argocd`
namespace), in which case you will need to authenticate directly to ArgoCD.

```sh
ARGOCD_PASSWORD=$(oc -n argocd extract secret/argocd-initial-admin-secret --to=-)
argocd login localhost:7080 --plaintext --grpc-web-root-path argocd --username admin --password "$ARGOCD_PASSWORD"
```

Now you can run `argocd` commands without additional arguments:

```sh
argocd app list
```

#### Keycloak

URL: <http://localhost:7080/keycloak/>

Username `temp-admin`. To get the password:

```
oc -n keycloak extract secret/keycloak-initial-admin --keys=password --to=-
```

#### LLDAP

URL: <http://localhost:7080/lldap/>

> [!NOTE]
> Because LLDAP does not support serving at a sub-path, this is actually
> just a redirect to <http://localhost:17170>.

Username `admin`. To get the password:

```
oc -n keycloak extract secret/lldap-credentials --keys=LLDAP_LDAP_USER_PASS --to=-
```

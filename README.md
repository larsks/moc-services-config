# moc-services-config

This repository manages the configuration of the `moc-services` [EKS] cluster. We use [ArgoCD] to automatically apply repository changes to the cluster.

## Cluster services

The moc-services cluster provides:

- [Keycloak], our IdP for the Open Accelerator OpenShift clusters

Support services include:

- [Postgres], managed by the [Crunchy Data Postgres Operator][pgo]
- [Cert-manager], for generating self-signed certificates
- [External secrets], for pulling secrets from AWS Secrets Manager and for copying secrets between namespaces

[EKS]: https://aws.amazon.com/eks/
[pgo]: https://github.com/crunchydata/postgres-operator
[cert-manger]: https://cert-manager.io/
[external secrets]: https://external-secrets.io/

## Working with ArgoCD

We deploy a single [ApplicationSet] from [`root.yaml`](base/applicationsets/root.yaml), patched for a specific deployment target (AWS or [Kind]). The ApplicationSet creates an ArgoCD [Application] for every directory in `overlays/<TARGET>`. For AWS, this means (as of this writing):

[applicationset]: https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/
[application]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications

- `applicationsets`
- `argocd`
- `cert-manager`
- `external-secrets`
- `keycloak`
- `metrics-server`
- `pgo`
- `postgres-common`

You can monitor the status of the applications using the [`argocd` cli][cli]. To see the status of all applications:

[cli]: https://argo-cd.readthedocs.io/en/stable/cli_installation/

```sh
$ argocd app list
NAME                     CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                                PATH                           TARGET
argocd/applicationsets   https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/applicationsets   main
argocd/argocd            https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/argocd            main
argocd/cert-manager      https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/cert-manager      main
argocd/external-secrets  https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/external-secrets  main
argocd/keycloak          https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/keycloak          main
argocd/metrics-server    https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/metrics-server    main
argocd/pgo               https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/pgo               main
argocd/postgres-common   https://kubernetes.default.svc             default  Synced  Healthy  Auto        <none>      https://github.com/cci-moc/moc-services-config.git  overlays/aws/postgres-common   main
```

To see the resources involved in a single application:

```sh
$ argocd app get postgres-common
Name:               argocd/postgres-common
Project:            default
Server:             https://kubernetes.default.svc
Namespace:
URL:                http://localhost:40781/applications/postgres-common
Source:
- Repo:             https://github.com/cci-moc/moc-services-config.git
  Target:           main
  Path:             overlays/aws/postgres-common
SyncWindow:         Sync Allowed
Sync Policy:        Automated
Sync Status:        Synced to main (bc6d248)
Health Status:      Healthy

GROUP                              KIND                NAMESPACE  NAME                              STATUS  HEALTH   HOOK  MESSAGE
                                   Namespace                      postgres                          Synced                 namespace/postgres serverside-applied
rbac.authorization.k8s.io          ClusterRole                    external-secrets-postgres-reader  Synced                 clusterrole.rbac.authorization.k8s.io/external-secrets-postgres-reader serverside-applied
rbac.authorization.k8s.io          RoleBinding         postgres   external-secrets-postgres-reader  Synced                 rolebinding.rbac.authorization.k8s.io/external-secrets-postgres-reader serverside-applied
external-secrets.io                ClusterSecretStore             postgres                          Synced  Healthy        clustersecretstore.external-secrets.io/postgres serverside-applied
postgres-operator.crunchydata.com  PostgresCluster     postgres   postgres                          Synced  Healthy        postgrescluster.postgres-operator.crunchydata.com/postgres serverside-applied
```

ArgoCD also provides a web interface. The easiest way to access it is to set up port forwarding from your local machine to the `argocd-server` service:

```sh
oc port-forward -n argocd svc/argocd-server 8080:80
```

While that command is running, the ArgoCD UI will be available at <http://localhost:8080>. You will log in as user `admin`. You can obtain the admin password by running:

```sh
oc -n argocd extract secret/argocd-initial-admin-secret --to=-
```

This will print the password on your console.

## Setting up a test environment

You can deploy this entire stack into a [Kind] cluster for local testing and development. You will need:

[kind]: https://kind.sigs.k8s.io/

- [Docker](https://www.docker.com/)
- [Kind]
- The `oc` cli

To set everything up, run:

```sh
./run-in-kind.sh
```

This will create a Kind cluster, deploy services into it, and leave credentials in `./kubeconfig`. When interacting with the cluster, you can specify the kubeconfig file on the command line:

```sh
oc --kubeconfig kubeconfig ...
```

Or set your `KUBECONFIG` environment variable:

```sh
export KUBECONFIG=$PWD/kubeconfig
```

When everything is deployed, Keycloak is available at <https://localhost:7443/>. Use the `extract-credentials.sh` script to show login credentials:

```sh
$ ./extract-credentials.sh
ArgoCD:
  Username: admin
  Password: ...
Keycloak:
  URL: https://localhost:7443/
  Username: temp-admin
  Password: ...
```

Successful output from the `run-in-kind.sh` scripts looks something like this:

```
2026-10-07 13:01:10 deleting existing moc-services cluster
2026-10-07 13:01:13 creating cluster
Creating cluster "moc-services-u0avy5" ...
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼️
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-moc-services-u0avy5"
You can now use your cluster with:

kubectl cluster-info --context kind-moc-services-u0avy5 --kubeconfig kubeconfig

Have a nice day! 👋
2026-10-07 13:01:29 installing argocd
Context "kind-moc-services-u0avy5" modified.
2026-10-07 13:01:32 waiting for argocd to become ready
deployment.apps/argocd-server condition met
deployment.apps/argocd-repo-server condition met
2026-10-07 13:02:23 applying applicationsets
2026-10-07 13:02:23 waiting for applicationsets to exist...
2026-10-07 13:02:24 waiting for applicationsets to sync...
2026-10-07 13:02:25 waiting for applicationsets to be healthy...
2026-10-07 13:02:25 waiting for argocd to exist...
2026-10-07 13:02:25 waiting for argocd to sync...
2026-10-07 13:02:31 waiting for argocd to be healthy...
2026-10-07 13:02:31 waiting for cert-manager to exist...
2026-10-07 13:02:32 waiting for cert-manager to sync...
2026-10-07 13:02:47 waiting for cert-manager to be healthy...
2026-10-07 13:02:47 waiting for external-secrets to exist...
2026-10-07 13:02:47 waiting for external-secrets to sync...
2026-10-07 13:02:48 waiting for external-secrets to be healthy...
2026-10-07 13:04:27 waiting for haproxy-ingress to exist...
2026-10-07 13:04:27 waiting for haproxy-ingress to sync...
2026-10-07 13:04:27 waiting for haproxy-ingress to be healthy...
2026-10-07 13:04:28 waiting for keycloak to exist...
2026-10-07 13:04:28 waiting for keycloak to sync...
2026-10-07 13:05:52 waiting for keycloak to be healthy...
2026-10-07 13:06:40 waiting for metrics-server to exist...
2026-10-07 13:06:40 waiting for metrics-server to sync...
2026-10-07 13:06:41 waiting for metrics-server to be healthy...
2026-10-07 13:06:41 waiting for pgo to exist...
2026-10-07 13:06:41 waiting for pgo to sync...
2026-10-07 13:06:41 waiting for pgo to be healthy...
2026-10-07 13:06:41 waiting for postgres-common to exist...
2026-10-07 13:06:41 waiting for postgres-common to sync...
2026-10-07 13:06:41 waiting for postgres-common to be healthy...
2026-10-07 13:06:42 all done.
```

## License

[Apache 2.0 License](LICENSE).

The code is provided as-is with no warranties.

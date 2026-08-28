First install the operator:

```
kustomize build oeprator --enable-helm | oc apply -f- --server-side
```

Then install the configuration:

```
oc apply -k instance
```

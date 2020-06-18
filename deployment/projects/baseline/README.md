# Logging stack

In alphabetical order:

- `fluent`
  - Contains the fluent-bit daemonset. This takes Kubernetes and workload logs and ships them to the shared services Fluentd. This is installed on all clusters.
- `ingress-nginx`
  - Contains public and private nginx ingress controllers. This is installed on all clusters.
- `linkerd`
  - Contains the captured and modified linkerd install manifest as well as the `kube-state-metrics` and `node-exporter` stacks. The included Prometheus is augmented with these services and is federated by the shared services Prometheus. This is installed on all clusters.
# Monitoring

`infra/platform` installs `kube-prometheus-stack` into the `monitoring` namespace. It includes Prometheus, Grafana, kube-state-metrics, node-exporter and Kubernetes dashboards.

Useful commands on the self-hosted runner:
```bash
aws eks update-kubeconfig --region ap-south-1 --name cloudshield-eks
kubectl -n monitoring get pods
kubectl -n monitoring get svc
```

Grafana is exposed as `ClusterIP` by default and should not be exposed directly to the public internet. Use a local tunnel:
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```
Then browse to `http://localhost:3000`. Retrieve the chart's generated admin password from its Kubernetes secret:
```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Dashboards include Kubernetes cluster/node/pod metrics. For application availability, the app exposes `/health`; the Kubernetes probes track health and Prometheus dashboards track pod restarts and workload resources. A dedicated blackbox exporter/Probe can be added if an external HTTP uptime SLI is required.

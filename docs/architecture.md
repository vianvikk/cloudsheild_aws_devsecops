# Architecture and design notes

```text
Developer push to GitHub
        |
        v
GitHub Actions (OIDC bootstrap workflow on GitHub-hosted runner)
        |
        v
Terraform bootstrap: VPC + subnets + NAT + EC2 self-hosted runner + IAM + S3 state
        |
        v
EC2 user-data installs Terraform, Docker, Trivy, SonarQube, Grafana and registers runner
        |
        v
GitHub Actions on self-hosted runner
  ├── Terraform platform: ECR + EKS + managed nodes + Prometheus/Grafana Helm chart
  └── CI/CD: tests → SonarQube → Trivy FS/image → Docker build → ECR push → kubectl deploy
                                                                  |
                                                                  v
                                                       EKS Service LoadBalancer
                                                                  |
                                                                  v
                                                     Public AWS load balancer URL
```

## Security controls
- GitHub-to-AWS bootstrap authentication uses OIDC rather than static AWS keys.
- Runner registration PAT is stored in Secrets Manager and fetched using EC2 instance role credentials.
- EBS root volume encrypted; EC2 metadata service requires IMDSv2.
- ECR scan-on-push and immutable tags enabled.
- Trivy scans source filesystem and built image; HIGH/CRITICAL findings fail the pipeline.
- Kubernetes pods run non-root, drop Linux capabilities, disallow privilege escalation and use read-only root filesystem.
- Public application ingress is only through the Kubernetes LoadBalancer service. SonarQube and host Grafana inbound rules default to a deny-all placeholder CIDR; use SSM port forwarding.

## Deliberate hackathon trade-offs
This sample uses one self-hosted runner with broad provisioning permissions for clarity and cost. A production implementation should separate Terraform provisioner and deployer identities, use a private EKS endpoint where practical, add TLS/WAF/Ingress, secret rotation, policy-as-code, SBOM signing/attestation, centralized logs/alerts, and multi-account environments.

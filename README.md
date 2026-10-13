# CloudShield DevSecOps — AWS Reference Implementation

End-to-end AWS implementation of the CloudShield DevSecOps Hackathon 2026 brief:
Terraform → GitHub Actions → SonarQube + Trivy → Docker → ECR → EKS → Prometheus/Grafana.

## Architecture
- **Bootstrap stack**: VPC (public/private subnets), S3 Terraform state bucket, EC2 self-hosted GitHub Actions runner, IAM instance profile, and automatic installation of Terraform, Docker, Trivy, SonarQube and Grafana.
- **Platform stack**: ECR, EKS, managed node group, EKS access for the runner, AWS Load Balancer integration via Kubernetes `Service type=LoadBalancer`.
- **CI/CD**: GitHub Actions workflows for bootstrap, platform provisioning, and push-triggered build/scan/publish/deploy.
- **Observability**: `kube-prometheus-stack` Helm chart (Prometheus + Grafana) in EKS; app health endpoint and Kubernetes/container metrics.

> This is a runnable reference scaffold, not a claim that AWS resources have already been deployed. You must configure AWS/GitHub settings and run the workflows. EKS, NAT Gateway, EC2 and load balancers incur charges. Destroy resources after evaluation.

## Prerequisites
1. An AWS account and a dedicated AWS IAM role/user with permissions to create VPC, EC2, IAM, S3, ECR, EKS, CloudWatch and ELB resources.
2. A GitHub repository for this code.
3. A GitHub fine-grained PAT stored in AWS Secrets Manager as a secret named `cloudshield/github-runner-pat`. Grant repository **Administration: Read and write** and **Metadata: Read** permissions so the EC2 startup script can request a short-lived runner registration token. The PAT is fetched at boot using the EC2 instance role; it is never committed to source.
4. GitHub repository Actions secrets:
   - `AWS_BOOTSTRAP_ROLE_ARN`: IAM role ARN that GitHub Actions can assume via OIDC for the bootstrap workflow.
   - `SONAR_TOKEN`: token generated from the automatically installed SonarQube server after its first login/setup.
5. GitHub repository variable:
   - `AWS_REGION` (for example `ap-south-1`)
6. Configure the AWS OIDC provider and a least-privilege role trusted by `token.actions.githubusercontent.com` for your repository. Do not use long-lived AWS access keys in GitHub.

## Deployment sequence
### 1. Configure GitHub/AWS
- Push this repository to GitHub.
- Configure AWS OIDC trust for `AWS_BOOTSTRAP_ROLE_ARN`.
- Create the Secrets Manager secret `cloudshield/github-runner-pat`.
- Add the GitHub Actions secret/variable listed above.

### 2. Provision bootstrap resources
- In GitHub, run **Actions → 01 Bootstrap AWS Runner → Run workflow**.
- The workflow creates an S3 state bucket if needed, initializes Terraform state, and provisions networking plus the self-hosted runner.
- Wait for EC2 cloud-init to finish (usually several minutes). In GitHub repository **Settings → Actions → Runners**, confirm the runner is online.
- SonarQube is at `http://<runner-public-ip>:9000` and runner-host Grafana at `http://<runner-public-ip>:3000`. Restrict inbound access to your own IP before using these; defaults intentionally do not expose these ports publicly.

### 3. Configure SonarQube
- Connect to the runner using AWS Systems Manager Session Manager (preferred). Use the SSM port-forwarding feature or create a temporary IP-restricted access rule if you need browser access.
- Complete first-login setup and generate a project token. Add it as GitHub Actions secret `SONAR_TOKEN`.
- The default SonarQube initial credentials may be changed on first login. Never commit tokens/passwords.

### 4. Provision platform
- Run **Actions → 02 Provision EKS Platform → Run workflow**. It runs on the self-hosted runner, creates ECR and EKS, and installs Prometheus/Grafana with Helm.
- The workflow writes EKS kubeconfig for subsequent deployments. Runner is persistent; keep it online.

### 5. Deploy application
- Push to `main` (or run **Actions → 03 CI Scan Build Deploy → Run workflow**).
- Pipeline runs tests, SonarQube analysis, Trivy filesystem and image scans, pushes an immutable commit-tagged image to ECR, and deploys it to EKS.
- The public application URL is printed by the workflow after the AWS load balancer is provisioned. Provisioning can take a few minutes.

## Repository layout
```text
.
├── app/                    # Vite React demo frontend + tests
├── docker/                 # Dockerfile and nginx configuration
├── infra/
│   ├── bootstrap/           # S3 state bootstrap + VPC + self-hosted runner
│   └── platform/            # ECR + EKS + node group + EKS access
├── k8s/                    # Application Deployment + LoadBalancer Service
├── monitoring/              # Helm values and dashboard guidance
├── scripts/                 # helper scripts
└── .github/workflows/       # bootstrap, platform, CI/CD workflows
```

## Security and operational notes
- No credentials are hardcoded. AWS access from GitHub uses OIDC; EC2 obtains its runner PAT from Secrets Manager via its instance role.
- The runner IAM policy is broad enough for this demo to provision EKS/ECR and deploy Kubernetes resources. For production, split bootstrap and platform roles, narrow resource ARNs/actions, and use a separate deployment role.
- SonarQube/Grafana run on the runner host as containers. Their ports are not opened to the internet by default; use SSM port forwarding or a temporary source-IP-restricted rule.
- Trivy is configured to fail on HIGH/CRITICAL findings. The first run may fail until vulnerabilities are fixed; this is intentional security gating.
- Terraform state contains infrastructure metadata. Keep the S3 bucket private, enable versioning/encryption, and restrict access.
- EKS and a NAT Gateway can be costly. Run `terraform destroy` in the platform directory first, then bootstrap directory, when finished.
- This project uses a sample frontend because the challenge brief did not include application source code. Replace `app/` with the provided frontend while preserving the health endpoint or update the probes.

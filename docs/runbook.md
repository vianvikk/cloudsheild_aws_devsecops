# Runbook

## Check runner bootstrap
```bash
aws ssm describe-instance-information
aws ec2 describe-instances --filters Name=tag:Name,Values=cloudshield-runner
```
Inspect `/var/log/cloud-init-output.log` on the EC2 host if runner registration fails.

## Verify cluster and app
```bash
aws eks update-kubeconfig --region ap-south-1 --name cloudshield-eks
kubectl get nodes
kubectl -n cloudshield get deploy,pods,svc
kubectl -n monitoring get pods
```

## Destroy resources (avoid ongoing charges)
1. Run `terraform destroy` in `infra/platform` using its S3 backend config.
2. Run `terraform destroy` in `infra/bootstrap` using its S3 backend config.
3. Delete the S3 state bucket only after Terraform state is no longer needed.
4. Delete the Secrets Manager runner PAT secret if it was created only for this project.

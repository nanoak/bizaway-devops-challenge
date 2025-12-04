# Terraform Infrastructure for AWS EKS

This Terraform code provisions:

- A dedicated VPC
- Private and public subnets
- An Amazon EKS cluster
- Managed EC2 node groups

The project is split into reusable modules:

- **modules/vpc** – Networking layer
- **modules/eks** – EKS control plane
- **modules/node_group** – Worker nodes

Environment-specific settings are stored under:

- environments/dev
- environments/prod

To deploy:

```
terraform init
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```
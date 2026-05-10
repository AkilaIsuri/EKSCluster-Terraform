# 🚀 Amazon EKS Cluster Provisioning using Terraform

A production-style Amazon EKS (Elastic Kubernetes Service) cluster deployment built using Terraform.  
This project provisions a secure and scalable Kubernetes environment in AWS with private worker nodes, networking, security configurations, logging, encryption, and managed node groups.

---

#  Architecture Overview

## High-Level Architecture

```text
Internet
   ↓
Internet Gateway
   ↓
Public Subnet
   ↓
NAT Gateway
   ↓
Private Subnet
   ↓
EKS Worker Nodes
   ↓
Pods & Containers
```

---

#  Infrastructure Components

This Terraform project provisions the following AWS resources:

## Networking
- VPC
- Public Subnets
- Private Subnets
- Internet Gateway
- NAT Gateway
- Route Tables
- Route Table Associations

## Security
- Security Groups
- IAM Roles & Policies
- IAM OIDC Provider (IRSA)
- KMS Encryption for Kubernetes Secrets

## EKS Components
- Amazon EKS Cluster
- Managed Node Groups
- Launch Templates
- EKS Addons
  - CoreDNS
  - kube-proxy
  - VPC CNI

## Observability
- CloudWatch Log Group
- Cluster Logging

---

#  Security Features

- Worker nodes deployed in private subnets
- Kubernetes secrets encrypted using AWS KMS
- Security Group-based communication controls
- IAM Roles for Service Accounts (IRSA)
- Encrypted EBS volumes
- IMDSv2 enforced on worker nodes

---

#  EKS Architecture

```text
Users
  ↓
Application Load Balancer
  ↓
Ingress Controller
  ↓
Kubernetes Services
  ↓
Pods
  ↓
Worker Nodes (Private Subnets)
```

---

#  Project Structure

```text
.
├── providers.tf
├── variables.tf
├── outputs.tf
├── main.tf
├── userdata.sh
├── modules/
│   ├── vpc/
│   ├── eks/
│   └── security/
└── terraform.tfvars
```

---

#  Prerequisites

Before deploying, ensure you have:

- AWS Account
- AWS CLI configured
- Terraform installed
- kubectl installed
- IAM permissions for EKS provisioning

---

# 🛠️ Terraform Commands

## Initialize Terraform

```bash
terraform init
```

## Validate Configuration

```bash
terraform validate
```

## Preview Infrastructure Changes

```bash
terraform plan
```

## Deploy Infrastructure

```bash
terraform apply
```

## Destroy Infrastructure

```bash
terraform destroy
```

---

#  Configure kubectl

After cluster creation:

```bash
aws eks update-kubeconfig \
  --region <aws-region> \
  --name <cluster-name>
```

Verify cluster access:

```bash
kubectl get nodes
```

---

#  EKS Addons Used

| Addon | Purpose |
|---|---|
| CoreDNS | Service discovery |
| kube-proxy | Kubernetes networking |
| VPC CNI | Pod networking & IP management |

---

# Kubernetes Secret Encryption

Secrets are encrypted at rest using AWS KMS.

```text
Kubernetes Secret
   ↓
AWS KMS Encryption
   ↓
Stored in etcd
```

---

#  Node Group Features

- Managed Node Groups
- Auto Scaling
- Launch Templates
- Encrypted EBS Volumes
- Monitoring Enabled
- Private Networking

---

#  Logging & Monitoring

Cluster logs enabled:
- API Server
- Audit Logs
- Scheduler
- Controller Manager
- Authenticator

Logs are stored in:
- Amazon CloudWatch

---

# High Availability Design

- Multi-AZ Deployment
- Private Worker Nodes
- NAT Gateway for outbound access
- Managed Kubernetes Control Plane

---

#  Key Terraform Concepts Used

- Modules
- Variables
- Outputs
- Dynamic Blocks
- Lifecycle Rules
- `create_before_destroy`
- `for_each`
- `merge()`
- Conditional Expressions

---

#  Learning Outcomes

This project demonstrates:
- AWS Networking
- Kubernetes Architecture
- Terraform Infrastructure as Code
- EKS Cluster Provisioning
- IAM & Security
- Cloud Infrastructure Design

---

# Notes

- Free-tier instance types such as `t3.micro` are recommended for learning environments.
- NAT Gateway incurs AWS charges even in small environments.
- Worker nodes are intentionally deployed in private subnets for security.

---


#  Future Improvements

- ArgoCD GitOps Integration
- Jenkins CI/CD Pipeline
- External DNS
- Cluster Autoscaler
- AWS Load Balancer Controller
- Monitoring with Prometheus & Grafana
- Helm-based application deployments

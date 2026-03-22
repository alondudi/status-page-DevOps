# Status Page DevOps Platform

This repository houses the complete Infrastructure as Code (IaC) and Continuous Deployment (GitOps) configuration for the highly-available Status Page application.

## 🏗️ Architecture Overview

The platform is designed for total reliability, autonomous self-healing, and infinite scalability. It completely separates the application source code from the infrastructure deployment code.

1. **Infrastructure (Terraform):** Fully autonomous provisioning of the underlying AWS environment, including the VPC, EKS Cluster, RDS PostgreSQL Database, and ElastiCache Redis.
2. **Kubernetes (Helm):** Dynamic templating of the Django application, carefully tuned with CPU/Memory limits and HTTP Liveness/Readiness probes for zero-downtime rolling updates.
3. **Continuous Deployment (ArgoCD):** 100% automated GitOps synchronizations. As soon as a new Docker image is built by GitHub Actions, the ArgoCD Image Updater detects it in ECR, automatically commits the new tag back to this repository, and ArgoCD seamlessly rolls out the update.
4. **Observability Stack:** A robust monitoring suite featuring Prometheus and Grafana. Prometheus autonomously scrapes live health metrics from Django, Redis, and ArgoCD via dedicated ServiceMonitors, while Grafana safely persists the data on dedicated AWS EBS physical volumes.

## 📂 Repository Structure

```text
├── .github/workflows/   # CI/CD pipeline automation for infrastructure and GitOps tasks
├── gitops/              # ArgoCD declarative manifests (The "Source of Truth" for the cluster)
│   ├── apps/            # Application definitions (monitoring, image-updater, status-page)
│   └── root-app.yaml    # The App-of-Apps root controller
├── status-page/         # The custom Helm Chart defining the Kubernetes deployment of the Django App
│   ├── templates/       # Kubernetes manifests (Deployment, Service, Ingress, HPA)
│   └── values.yaml      # Environment-specific configuration and image tags
└── terraform/           # Infrastructure as Code
    ├── eks.tf           # Elastic Kubernetes Service and Node Group definitions
    ├── databases.tf     # RDS (PostgreSQL) and ElastiCache (Redis)
    └── vpc.tf           # Networking, Subnets, and NAT Gateways
```

## 🚀 Deployment Playbook

### 1. Provision AWS Infrastructure
Before accessing the cluster, you must provision the AWS baseline resources:
```bash
cd terraform
terraform init
terraform apply
```
*This command safely builds the VPC, EKS Cluster, RDS Database, and Redis Cache from scratch.*

### 2. Connect to the EKS Cluster
Once Terraform completes, securely connect your local `kubectl` to the new EKS cluster:
```bash
aws eks update-kubeconfig --region us-east-1 --name status-page-cluster-aa
```

### 3. Bootstrap ArgoCD (GitOps)
The entire application stack is deployed through ArgoCD. Install ArgoCD on the cluster, and then apply the `root-app.yaml` manifest. ArgoCD will autonomously read this repository and deploy Prometheus, Grafana, the Image Updater, and the Status Page.
```bash
kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable
kubectl apply -f gitops/root-app.yaml
```

## 🔄 The CI/CD Pipeline Flow

This project uses an advanced GitOps deployment strategy:
1. **Developer Push:** A developer pushes Python code to the `status-page-app` repository.
2. **GitHub Actions CI:** The CI pipeline builds the code, runs tests, and pushes a new tagged container image to **Amazon ECR**.
3. **ArgoCD Image Updater:** Constantly watches ECR. When it sees the new tag, it automatically commits that tag back to this repository.
4. **ArgoCD Server:** Detects the commit in this repository and safely performs a rolling update to the live EKS cluster without dropping a single user request.

## 🛡️ Disaster Recovery
Because 100% of the environment is defined declaratively using Terraform and ArgoCD, if the `us-east-1` AWS region experiences an unrecoverable failure, the entire company's architecture can be rebuilt from scratch into a new region in less than 20 minutes using a single `terraform apply` command.
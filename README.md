# Status Page — DevOps & GitOps Platform

[![Terraform CI](https://github.com/alondudi/status-page-DevOps/actions/workflows/terraform-ci.yml/badge.svg?branch=main)](https://github.com/alondudi/status-page-DevOps/actions/workflows/terraform-ci.yml)
[![App CI](https://github.com/alondudi/status-page-app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/alondudi/status-page-app/actions/workflows/ci.yml)

[![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20RDS%20%7C%20ElastiCache-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-Charts-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF7B4D?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?logo=grafana&logoColor=white)](https://grafana.com/)
[![Docker](https://img.shields.io/badge/Docker-ECR-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)

## 🔗 Related repositories

| Repository | Purpose |
|------------|---------|
| **[status-page-app](https://github.com/alondudi/status-page-app)** | Django Status Page **source code**, `Dockerfile`, and **GitHub Actions** that build & push images to **Amazon ECR**. Clone URL: `https://github.com/alondudi/status-page-app.git` |
| **This repo (`status-page-DevOps`)** | AWS (Terraform), Helm chart, Argo CD GitOps manifests |


Infrastructure-as-code (Terraform), Kubernetes deployment (Helm), and GitOps (Argo CD) for a **Django-based Status Page** running on **AWS EKS**, backed by **Amazon RDS (PostgreSQL)** and **Amazon ElastiCache (Redis)**.

> **Related repository:** application source and Docker build live in [`status-page-app`](https://github.com/alondudi/status-page-app) (separate repo). This repo is the **cluster + cloud** source of truth.

---

## Table of contents

- [Tech stack](#tech-stack)
- [What this repo does](#what-this-repo-does)
- [High-level architecture](#high-level-architecture)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Bootstrap: from zero to running](#bootstrap-from-zero-to-running)
- [Day-2 operations](#day-2-operations)
- [CI/CD](#cicd)
- [Observability](#observability)
- [Security notes](#security-notes)
- [Troubleshooting](#troubleshooting)

---

## Tech stack

End-to-end stack for the Status Page platform (application + cloud + cluster).

| Layer | Technologies |
|--------|----------------|
| **Application** | [Python](https://www.python.org/) 3.10+, [Django](https://www.djangoproject.com/), [Gunicorn](https://gunicorn.org/), [WhiteNoise](https://whitenoise.readthedocs.io/) (static files), [Django REST Framework](https://www.django-rest-framework.org/), [django-rq](https://github.com/rq/django-rq) + [Redis](https://redis.io/) (queues / cache), [PostgreSQL](https://www.postgresql.org/) (via `psycopg2`), optional [django-prometheus](https://github.com/korfuri/django-prometheus) for `/metrics` |
| **Container** | [Docker](https://www.docker.com/), images stored in **Amazon [ECR](https://aws.amazon.com/ecr/)** |
| **Cloud (AWS)** | [Amazon EKS](https://aws.amazon.com/eks/), [VPC](https://aws.amazon.com/vpc/) + subnets + [NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html), [RDS for PostgreSQL](https://aws.amazon.com/rds/postgresql/), [ElastiCache for Redis](https://aws.amazon.com/elasticache/redis/), [Application Load Balancer](https://aws.amazon.com/elasticloadbalancing/application-load-balancer/) (via Ingress), [Secrets Manager](https://aws.amazon.com/secrets-manager/), [IAM](https://aws.amazon.com/iam/) + **OIDC** for GitHub Actions |
| **Kubernetes** | [Kubernetes](https://kubernetes.io/), [Helm](https://helm.sh/) charts (`status-page/`), [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/), [External Secrets Operator](https://external-secrets.io/) |
| **GitOps & delivery** | [Argo CD](https://argo-cd.readthedocs.io/), [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/) (optional tag bumps from ECR), [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) |
| **Observability** | [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/), [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) (Helm), [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) + **ServiceMonitors**, [redis_exporter](https://github.com/oliver006/redis_exporter) |
| **Infrastructure as code** | [Terraform](https://www.terraform.io/) (`terraform/`), [Terraform AWS modules](https://registry.terraform.io/namespaces/terraform-aws-modules) (e.g. VPC), optional [tflint](https://github.com/terraform-linters/tflint) / [tfsec](https://github.com/aquasecurity/tfsec) / [Infracost](https://www.infracost.io/) in CI |
| **CI/CD** | [GitHub Actions](https://github.com/features/actions) — app repo: build & push to ECR; this repo: Terraform validate / plan / apply |

---

## What this repo does

| Layer | Tooling | Purpose |
|--------|---------|---------|
| **Cloud** | Terraform (`terraform/`) | VPC, EKS, node groups, RDS, ElastiCache, ECR, IAM, ALB controller hooks, Argo CD install (Helm), secrets in Secrets Manager, etc. |
| **Cluster apps** | Argo CD (`gitops/`) | App-of-apps deploys monitoring, status-page Helm chart, autoscaler, metrics exporters, optional tooling |
| **Application on K8s** | Helm (`status-page/`) | Deployment, worker, Services, Ingress (ALB), ConfigMap, External Secrets, probes, optional `ServiceMonitor` |

---

## High-level architecture

```text
                    Internet
                        │
                        ▼
              AWS Load Balancer Controller
                        │
            Ingress (ALB) → Service → Pods
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   Django (web)    RQ worker      Prometheus/Grafana
   Gunicorn :8000   (background)   (monitoring NS)
        │               │
        └───────┬───────┘
                ▼
    RDS PostgreSQL          ElastiCache Redis
    (private subnets)       (private subnets)
```

- **Web**: Django + Gunicorn (container port **8000**; Service maps **80 → 8000**).
- **Worker**: `manage.py rqworker --with-scheduler` for **django-rq** queues (emails, async work).
- **Data**: PostgreSQL and Redis are **managed AWS services**; Kubernetes uses **`ExternalName` Services** (`db`, `redis`) to stable DNS names where applicable.
- **Ingress**: ALB annotations in `status-page/templates/08-ingress.yaml` (HTTP/HTTPS, health checks).

---

## Repository layout

```text
.
├── terraform/                 # AWS + EKS + data stores + Argo CD (Helm) + IAM/OIDC pieces
├── gitops/
│   ├── root-app.yaml          # Argo CD "app of apps" → syncs everything under gitops/apps
│   └── apps/                  # Individual Argo CD Application manifests + raw K8s where needed
├── status-page/               # Helm chart for the Status Page workload (namespace: status-page)
│   ├── Chart.yaml
│   ├── values.yaml            # Image tag, DB/Redis endpoints, ingress host, resources, etc.
│   └── templates/
├── docker/                    # Local compose for dev (Postgres + Redis + optional image)
├── .github/workflows/         # Terraform validate/lint + optional apply + Infracost on PRs
└── README.md                  # This file
```

### GitOps apps (`gitops/apps/`)

Typical manifests in this repo (names may evolve):

| Manifest | Role |
|----------|------|
| `status-page.yaml` | Argo CD **Application** for the Helm chart; **Argo CD Image Updater** annotations |
| `monitoring.yaml` | **kube-prometheus-stack** (Prometheus, Grafana, operators) |
| `image-updater.yaml` | Argo CD Image Updater configuration |
| `ai-mcp-bastion.yaml` | Optional tooling pod (if used) |
| `cluster-autoscaler.yaml` | Cluster Autoscaler |
| `grafana-secret.yaml` | ExternalSecret / credentials wiring for Grafana admin |
| `redis-exporter.yaml` | **redis_exporter** Deployment + Service + ServiceMonitor → ElastiCache |
| `argocd-metrics.yaml` + `argocd-metrics-services.yaml` | Scrape Argo CD metrics |
| `status-page-servicemonitor.yaml` | Extra ServiceMonitor for Django `/metrics` (if not using chart-only monitor) |

> **Note:** The Helm chart can also render a `ServiceMonitor` when `metrics.enabled: true` (`status-page/templates/10-service-monitor.yaml`). If you maintain **both** chart and standalone YAML, ensure you do not duplicate conflicting scrape configs.

---

## Prerequisites

- **AWS account** with permissions for EKS, VPC, RDS, ElastiCache, IAM, ECR, etc.
- **Tools locally:** `terraform` (≥ 1.x), `kubectl`, `helm` (optional), **AWS CLI** configured.
- **GitHub:**  
  - OIDC / IAM roles for **Terraform apply** (see workflow `AWS_ROLE_ARN` secret).  
  - OIDC role for **app CI** pushing to ECR (`github-actions-ecr-role-AA` in app workflow).
- **Domains / TLS:** Ingress uses ACM certificate ARN in `values.yaml` when set (`certificateArn`).

---

## Bootstrap: from zero to running

### 1) Provision cloud infrastructure

```bash
cd terraform
terraform init
terraform apply
```

Creates (among other things) VPC, EKS cluster + nodes, RDS, Redis, ECR, Argo CD (via Terraform Helm release), and supporting IAM/security groups.

### 2) Configure `kubectl`

```bash
aws eks update-kubeconfig --region us-east-1 --name status-page-cluster-aa
```

(Adjust **region** / **cluster name** if you changed them in Terraform.)

### 3) GitOps: deploy workloads

Argo CD is installed by Terraform; sync the **root application**:

```bash
kubectl apply -f gitops/root-app.yaml
```

Argo CD will reconcile `gitops/apps/` and deploy:

- `kube-prometheus-stack` into `monitoring`
- `status-page` Helm chart into `status-page`
- other configured apps

### 4) Build and push the application image

Application Dockerfile and CI live in **`status-page-app`**. On push to `main`, GitHub Actions:

- Builds and pushes:  
  `992382545251.dkr.ecr.us-east-1.amazonaws.com/alon-aviad-repo:status-page-<run_number>`

**Argo CD Image Updater** (annotations on `gitops/apps/status-page.yaml`) can update `status-page/values.yaml` `image.tag` to match new ECR tags (regex `^status-page-[0-9]+$`), then Argo CD rolls out the Deployment.

---

## Day-2 operations

### Change configuration (non-secret)

Edit `status-page/values.yaml` (replicas, resources, ingress host, `metrics.enabled`, etc.) and merge to `main`; Argo CD syncs.

### Database password

RDS credentials are sourced from **AWS Secrets Manager** via **External Secrets** (`status-page/templates/07-external-secret.yaml`) into Kubernetes Secret `status-page-secret` (key `DB_PASSWORD`).

### Verify workloads

```bash
kubectl get pods -n status-page
kubectl get pods -n monitoring
kubectl get ingress -n status-page
```

### Local development stack (optional)

`docker/docker-compose.yml` spins up Postgres + Redis + (optionally) pinned ECR images for web/worker. Useful for quick integration tests; **do not** commit production secrets into compose files long-term.

---

## CI/CD

### This repo (`status-page-DevOps`)

Workflow: `.github/workflows/terraform-ci.yml`

- **On PR / push** (paths `terraform/**`): `fmt`, `init`, `validate`, **tflint**, **tfsec** (soft fail).
- **On PR**: **Infracost** comment (requires `INFRACOST_API_KEY`).
- **On push to `main`**: `terraform apply` (uses `AWS_ROLE_ARN` secret, **production** environment — may require manual approval).

### Application repo (`status-page-app`)

Workflow: `.github/workflows/ci.yml`

- **On push to `main`**: build Docker image and push to **ECR** with tag `status-page-${{ github.run_number }}`.

---

## Observability

### Stack

- **kube-prometheus-stack** (`gitops/apps/monitoring.yaml`): Prometheus + Grafana + Prometheus Operator.
- **Persistence**: Grafana (5Gi) and Prometheus (10Gi) PVCs configured in Helm values.
- **Scrape config**: `serviceMonitorSelector: {}` and `serviceMonitorNamespaceSelector: {}` so **ServiceMonitors in any namespace** are picked up.

### Django metrics

- Application should expose Prometheus metrics (e.g. **`django-prometheus`**) at **`/metrics`** on the app port.
- Helm: `metrics.enabled: true` renders `ServiceMonitor` targeting Service port named **`http`**, path `/metrics`.

### Redis (ElastiCache)

- **`redis_exporter`** in `monitoring` (`gitops/apps/redis-exporter.yaml`) scrapes Redis; `ServiceMonitor` on port `metrics`.

### Grafana

- Service type **LoadBalancer** (NLB class) for external access; admin credentials via Kubernetes Secret (see `grafana-secret` + Terraform Secrets Manager wiring).

---

## Security notes

1. **Do not store long-lived secrets in Git**  
   The Helm chart’s `ConfigMap` currently includes sensitive fields in some revisions (e.g. `SECRET_KEY`, email app passwords). **Recommended:** move all secrets to **AWS Secrets Manager** + **ExternalSecret**, and keep ConfigMap non-sensitive only.

2. **Least privilege**  
   Review IAM roles for GitHub OIDC (Terraform apply vs ECR push) and EKS node/instance roles.

3. **Network**  
   RDS and Redis security groups should allow traffic only from the VPC / EKS data plane, not from the public internet.

4. **Argo CD**  
   Protect the Argo CD UI/API; use strong admin passwords and consider SSO for teams.

---

## Troubleshooting

| Symptom | Things to check |
|---------|------------------|
| Pods `ImagePullBackOff` | ECR pull secret `ecr-pull-secret`, image tag exists, IAM/ECR permissions |
| App not reachable | ALB controller running, Ingress status, target group health, security groups |
| DB connection errors | RDS security group, `DB_*` env from ConfigMap/Secret, RDS endpoint |
| Redis connection errors | ElastiCache SG, `REDIS_*` env, `ExternalName` Service |
| RQ / emails not processing | `status-page-worker` pod running, Redis reachable, SMTP settings |
| No Prometheus metrics | `/metrics` returns 200 from inside cluster; Service port name `http`; `ServiceMonitor` labels/selectors; `metrics.enabled` |
| Terraform CI fails | `terraform validate` output, AWS OIDC role trust policy, backend config |

---

Author Alon Dahan
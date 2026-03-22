# Status Page Architecture - Eraser.io Diagram

## How to use this:
1. Go to https://eraser.io
2. Create a new diagram
3. Copy the code below and paste it into the Eraser editor
4. The diagram will auto-generate

---

## Eraser.io Code

```
# External Users & Systems
[End Users] <---> [Browser]

# CDN & DNS Layer
[Browser] <---> [Route 53]
[Route 53] <---> [CloudFront/ALB]

# Kubernetes Cluster (EKS)
[CloudFront/ALB] <---> [EKS Cluster]

# Inside EKS - Kubernetes Namespace (default)
group "Kubernetes Cluster" {
    group "Status Page Application" {
        [Ingress Controller] <---> [Service: status-page (ClusterIP:80)]
        [Service: status-page] <---> [Deployment: status-page-web]
        [Deployment: status-page-web] ---|replicas: 2| [Pod-Web-1]
        [Deployment: status-page-web] ---|replicas: 2| [Pod-Web-2]
    }
    
    group "Worker Queue System" {
        [Deployment: status-page-worker] ---|replicas: 1| [Pod-Worker]
        [Pod-Worker] --> [RQ Worker Process]
        [RQ Worker Process] --> |processes tasks| [Redis Queue]
    }
    
    group "Configuration & Secrets" {
        [ConfigMap: status-page-config]
        [Secret: status-page-secret]
    }
}

# Web Pods - Django Application
[Pod-Web-1] --> |reads config from| [ConfigMap: status-page-config]
[Pod-Web-1] --> |reads secrets from| [Secret: status-page-secret]
[Pod-Web-2] --> |reads config from| [ConfigMap: status-page-config]
[Pod-Web-2] --> |reads config from| [Secret: status-page-secret]

# Worker Pod
[Pod-Worker] --> |reads config from| [ConfigMap: status-page-config]
[Pod-Worker] --> |reads secrets from| [Secret: status-page-secret]

# External Data Services (AWS)
group "AWS Data Layer" {
    [RDS PostgreSQL] ---|statuspage DB|
    [ElastiCache Redis] ---|task queue|
}

# Database Connections
[Pod-Web-1] <---> |JDBC/psycopg2| [RDS PostgreSQL]
[Pod-Web-2] <---> |JDBC/psycopg2| [RDS PostgreSQL]
[Pod-Worker] <---> |psycopg2| [RDS PostgreSQL]

# Redis Connections
[Pod-Web-1] <---> |socket| [ElastiCache Redis]
[Pod-Web-2] <---> |socket| [ElastiCache Redis]
[Pod-Worker] <---> |socket| [ElastiCache Redis]

# External Services
[Pod-Web-1] --> |SMTP| [Gmail SMTP Server]
[Pod-Worker] --> |SMTP| [Gmail SMTP Server]

# ArgoCD GitOps Management
[ArgoCD] --> |syncs manifests| [EKS Cluster]
[ArgoCD] --> |monitors| [GitHub: status-page-DevOps repo]

# Monitoring & Metrics
[Pod-Web-1] --> |prometheus metrics| [Prometheus]
[Pod-Web-2] --> |prometheus metrics| [Prometheus]
[Pod-Worker] --> |prometheus metrics| [Prometheus]
[Prometheus] --> |visualizes| [Grafana]

# VPC Network
group "AWS VPC" {
    group "Public Subnets" {
        [NAT Gateway]
    }
    group "Private Subnets" {
        [EKS Cluster]
        [RDS PostgreSQL]
        [ElastiCache Redis]
    }
}

# Data Flow Examples
note "Key Data Flows:" {
    "1. User Email Verification:"
    "   User submits email -> Web pod enqueues task to Redis"
    "   -> Worker reads from Redis -> Sends email via SMTP"
    ""
    "2. Status Page Display:"
    "   Browser request -> ALB -> Ingress -> Service -> Web pod"
    "   -> Pod queries PostgreSQL -> Returns status HTML/JSON"
    ""
    "3. Configuration Management:"
    "   Terraform -> K8s Secrets & ConfigMaps"
    "   -> Pods read at startup via envFrom"
}
```

---

## Architecture Components Summary

### Frontend Layer
- **End Users**: Access status page via browser
- **Route 53**: DNS routing
- **ALB (Application Load Balancer)**: Distributes traffic to EKS

### Kubernetes (EKS) Layer
- **Ingress Controller**: Routes traffic to services
- **Status Page Service**: ClusterIP service exposing port 80
- **Web Pods**: Django WSGI application (gunicorn), runs on port 8000
- **Worker Pods**: RQ workers process background tasks

### Database Layer
- **RDS PostgreSQL**: Main application database
  - Stores components, incidents, users, metrics, etc.
- **ElastiCache Redis**: 
  - Task queue for async jobs (email sending, etc.)
  - Caching layer for performance

### Configuration Management
- **ConfigMap**: Holds non-sensitive config (DB host, Redis host, etc.)
- **AWS Secrets Manager**: Stores passwords, API keys (referenced by External Secrets)
- **External Secrets Operator**: Syncs secrets from AWS to K8s

### Application Flow

#### Email Subscription (Async)
1. User submits email via web UI
2. Web pod enqueues task in Redis queue
3. Worker pod reads queue
4. Worker sends email via Gmail SMTP

#### Status Page Display (Sync)
1. User hits endpoint
2. ALB routes to available pod
3. Pod queries PostgreSQL
4. Returns JSON/HTML response

### Key Technologies
- **Framework**: Django 4.1.4 (Python)
- **Web Server**: Gunicorn
- **Task Queue**: RQ (Redis Queue)
- **Database**: PostgreSQL 10+
- **Cache**: Redis 4.0+
- **Container**: Docker
- **Orchestration**: Kubernetes (EKS)
- **Infrastructure as Code**: Terraform
- **GitOps**: ArgoCD
- **Monitoring**: Prometheus + Grafana

### Security Features
- 2FA (OTP/YubiKey) authentication
- Encrypted Redis connections (optional SSL)
- SSL/TLS for all external connections
- AWS IAM roles for pod authentication
- Secret rotation via AWS Secrets Manager

---

## Deployment Flow

1. **Code Push** → GitHub (status-page-DevOps)
2. **ArgoCD** monitors GitHub
3. **ArgoCD** syncs K8s manifests to EKS
4. **Helm Chart** deploys:
   - ConfigMap with app settings
   - Secret with credentials
   - Web deployment (2 replicas)
   - Worker deployment (1 replica)
   - Service and Ingress
5. **External Secrets** syncs AWS Secrets Manager to K8s
6. **Pods start** and read configuration
7. **Ingress** exposes service to ALB
8. **Users access** statuspage-aa.click

---

## Important Files Structure

```
status-page-DevOps/
├── terraform/            # Infrastructure as Code
│   ├── eks.tf           # EKS cluster, node groups
│   ├── rds.tf           # PostgreSQL database
│   ├── ec.tf            # ElastiCache (Redis)
│   ├── vpc.tf           # VPC, subnets, NAT
│   ├── dns.tf           # Route 53
│   ├── alb.tf           # ALB controller
│   └── secrets.tf       # AWS Secrets Manager
│
├── status-page/         # Helm Chart
│   ├── Chart.yaml
│   ├── values.yaml      # Configuration values
│   └── templates/
│       ├── 01-configmap.yaml      # App config
│       ├── 02-deployment.yaml     # Web deployment
│       ├── 03-service.yaml        # K8s service
│       ├── 06-secret-store.yaml   # External Secrets config
│       ├── 07-external-secret.yaml # AWS Secrets sync
│       ├── 08-ingress.yaml        # Ingress rules
│       └── 09-worker-deployment.yaml # RQ worker
│
├── gitops/              # ArgoCD Applications
│   ├── root-app.yaml    # Root application
│   └── apps/            # Individual apps
│
└── docker/              # Local development
    ├── docker-compose.yml
    └── Dockerfile

status-page-app/
├── statuspage/          # Django application
│   ├── components/      # Status components
│   ├── incidents/       # Incident management
│   ├── maintenances/    # Maintenance windows
│   ├── metrics/         # Metrics integration
│   ├── subscribers/     # Email subscribers
│   ├── queuing/         # RQ integration
│   ├── manage.py        # Django CLI
│   └── settings/        # Django settings
│
├── requirements.txt     # Python dependencies
├── Dockerfile          # Container definition
└── entrypoint.sh       # Container startup script
```


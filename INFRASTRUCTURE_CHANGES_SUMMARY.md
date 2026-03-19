# Summary of Changes - Email Subscription Bug Fix

## Overview
**Problem**: Users who subscribe with email don't receive verification emails
**Root Cause**: Infrastructure issue - No RQ worker in Kubernetes to process queued email tasks
**Solution**: Add RQ worker deployment + make configuration environment-variable driven

---

## Application Code Changes

### File: `statuspage/statuspage/configuration.py`
**Status**: ✅ MODIFIED

**Changes**:
1. Added `import os` at the top
2. Changed all configuration values to use `os.getenv()` instead of hardcoded values
3. Now supports these environment variables:

**Database Config**:
```python
DATABASE = {
    'NAME': os.getenv('DB_NAME', 'statuspage'),
    'USER': os.getenv('DB_USER', 'dbadmin'),
    'PASSWORD': os.getenv('DB_PASSWORD', ':9Zt3=78LeIuK*A?'),
    'HOST': os.getenv('DB_HOST', 'db'),
    'PORT': os.getenv('DB_PORT', ''),
    'CONN_MAX_AGE': 300,
}
```

**Redis Config**:
```python
REDIS = {
    'tasks': {
        'HOST': os.getenv('REDIS_HOST', 'redis'),
        'PORT': int(os.getenv('REDIS_PORT', 6379)),
        'PASSWORD': os.getenv('REDIS_PASSWORD', ''),
        'DATABASE': 0,
        'SSL': os.getenv('REDIS_SSL', 'False').lower() == 'true',
    },
    'caching': { ... }
}
```

**Email Config** (NEW):
```python
EMAIL = {
    'SERVER': os.getenv('EMAIL_SERVER', 'smtp.gmail.com'),
    'PORT': int(os.getenv('EMAIL_PORT', 465)),
    'USERNAME': os.getenv('EMAIL_USERNAME', 'statuspageaa@gmail.com'),
    'PASSWORD': os.getenv('EMAIL_PASSWORD', ''),
    'USE_SSL': os.getenv('EMAIL_USE_SSL', 'True').lower() == 'true',
    'USE_TLS': os.getenv('EMAIL_USE_TLS', 'False').lower() == 'true',
    'TIMEOUT': int(os.getenv('EMAIL_TIMEOUT', 60)),
    'FROM_EMAIL': os.getenv('EMAIL_FROM_EMAIL', os.getenv('EMAIL_USERNAME', 'statuspageaa@gmail.com')),
}
```

**Other**:
```python
SITE_URL = os.getenv('SITE_URL', "https://statuspage-aa.click/")
SECRET_KEY = os.getenv('SECRET_KEY', 'HDdnCJ%y4oKGSB%UIpOX$1R0*89HZoD)U%Yil2%o&@L8fypVC-')
```

---

## Infrastructure Changes

### File: `status-page/templates/09-worker-deployment.yaml`
**Status**: ✅ NEW FILE (CRITICAL)

**Content**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: status-page-worker
spec:
  replicas: 1
  containers:
  - name: status-page-worker
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
    command: ["python3", "statuspage/manage.py", "rqworker", "--with-scheduler"]
    envFrom:
    - configMapRef:
        name: status-page-config
    - secretRef:
        name: status-page-secret
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
```

**Purpose**: This deployment runs the RQ worker that processes email tasks from the Redis queue. This was completely missing before!

---

### File: `status-page/values.yaml`
**Status**: ✅ MODIFIED

**Changes**: Added email configuration section:
```yaml
email:
  server: "smtp.gmail.com"
  port: "465"
  username: "statuspageaa@gmail.com"
  use_ssl: "True"
  use_tls: "False"
  timeout: "60"
  # password should be stored in AWS Secrets Manager
```

---

### File: `status-page/templates/01-configmap.yaml`
**Status**: ✅ MODIFIED

**Before**:
```yaml
data:
  DB_HOST: "..."
  DB_PORT: "..."
  DB_NAME: "..."
  DB_USER: "..."
  REDIS_HOST: "..."
  REDIS_PORT: "..."
```

**After** (added email config):
```yaml
data:
  # ... existing database and redis config ...
  
  # Email Configuration
  EMAIL_SERVER: "{{ .Values.email.server }}"
  EMAIL_PORT: "{{ .Values.email.port }}"
  EMAIL_USERNAME: "{{ .Values.email.username }}"
  EMAIL_USE_SSL: "{{ .Values.email.use_ssl }}"
  EMAIL_USE_TLS: "{{ .Values.email.use_tls }}"
  EMAIL_TIMEOUT: "{{ .Values.email.timeout }}"
  EMAIL_FROM_EMAIL: "{{ .Values.email.username }}"
```

---

### File: `status-page/templates/07-external-secret.yaml`
**Status**: ✅ MODIFIED

**Before**:
```yaml
data:
  - secretKey: DB_PASSWORD
    remoteRef:
      key: status-page-db-aa-credentials
      property: password
```

**After** (added email password):
```yaml
data:
  - secretKey: DB_PASSWORD
    remoteRef:
      key: status-page-db-aa-credentials
      property: password
  - secretKey: EMAIL_PASSWORD
    remoteRef:
      key: status-page-db-aa-credentials
      property: email_password
```

This pulls the email password from AWS Secrets Manager instead of hardcoding it.

---

## Summary Table

| File | Type | Change | Reason |
|------|------|--------|--------|
| `configuration.py` | App | Use env vars | Enable K8s injection of config |
| `09-worker-deployment.yaml` | K8s | **NEW** | Process email tasks from queue |
| `values.yaml` | K8s | Add email section | Helm values for email config |
| `01-configmap.yaml` | K8s | Add EMAIL_* vars | Inject email config to containers |
| `07-external-secret.yaml` | K8s | Add EMAIL_PASSWORD | Fetch password from AWS Secrets |

---

## What This Fixes

### Before
```
User subscribes
    ↓
Email task enqueued to Redis
    ↓
❌ NO WORKER - task sits in queue forever
    ↓
No email sent
```

### After
```
User subscribes
    ↓
Email task enqueued to Redis (web pod)
    ↓
✅ WORKER POD processes task
    ↓
Email sent via SMTP
    ↓
User receives email ✓
```

---

## Data Flow

### Application Flow
```
Subscriber Model
  ↓
send_mail() method
  ↓
django_rq.enqueue() → Redis Queue
  ↓
RQ Worker reads from queue
  ↓
utilities/utils.py send_mail() function
  ↓
Django send_mail() with SMTP
  ↓
Email delivered
```

### Configuration Flow (NEW)
```
Kubernetes Node
  ↓
ConfigMap (EMAIL_SERVER, EMAIL_USERNAME, etc.)
  ↓
↓
Secret (EMAIL_PASSWORD from AWS Secrets Manager)
  ↓
Container Environment Variables
  ↓
os.getenv() in configuration.py
  ↓
Django settings.EMAIL
  ↓
SMTP connection
```

---

## Environment Variables Reference

All these are now supported and can be injected via Kubernetes:

```
# Database
DB_NAME=statuspage
DB_USER=dbadmin
DB_PASSWORD=...
DB_HOST=status-page-db-aa.cx248m4we6k7.us-east-1.rds.amazonaws.com
DB_PORT=5432

# Redis
REDIS_HOST=status-page-redis-aa.7fftml.0001.use1.cache.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_SSL=False

# Email
EMAIL_SERVER=smtp.gmail.com
EMAIL_PORT=465
EMAIL_USERNAME=statuspageaa@gmail.com
EMAIL_PASSWORD=<from AWS Secrets Manager>
EMAIL_USE_SSL=True
EMAIL_USE_TLS=False
EMAIL_TIMEOUT=60
EMAIL_FROM_EMAIL=statuspageaa@gmail.com

# Site
SITE_URL=https://statuspage-aa.click/
SECRET_KEY=...
```

---

## Backward Compatibility

✅ All changes are backward compatible:
- If environment variables are not set, default values are used
- Existing hardcoded values in configuration.py act as defaults
- No breaking changes to the application code

---

## Next Steps for You

1. **Update AWS Secrets Manager** with email_password
2. **Rebuild Docker image** with latest code
3. **Update GitOps repo** with new image tag
4. **Push to git** - ArgoCD will sync automatically
5. **Verify** worker pod is running and processing emails

See `QUICK_ACTION_CHECKLIST.md` for detailed steps.

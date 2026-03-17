# =============================================================================
# ArgoCD — GitOps Continuous Deployment
# Deploys ArgoCD via Helm and creates an Application for status-page
# =============================================================================

# -----------------------------------------------------------------------------
# 1. ArgoCD Namespace
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [aws_eks_node_group.nodes]
}

# -----------------------------------------------------------------------------
# 2. ArgoCD Helm Release
# -----------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "5.55.0"

  # שים לב! מחקנו מכאן את כל ה-set. טרפורם רק מתניע את המערכת.

  depends_on = [
    kubernetes_namespace.argocd
  ]
}
resource "kubectl_manifest" "argocd_app" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: status-page
      namespace: argocd
      annotations:
        argocd-image-updater.argoproj.io/image-list: web=992382545251.dkr.ecr.us-east-1.amazonaws.com/alon-aviad-repo
        argocd-image-updater.argoproj.io/web.update-strategy: latest
        argocd-image-updater.argoproj.io/web.helm.image-name: image.repository
        argocd-image-updater.argoproj.io/web.helm.image-tag: image.tag
        argocd-image-updater.argoproj.io/write-back-method: argocd
    spec:
      project: default
      source:
        repoURL: "https://github.com/alondudi/status-page-DevOps.git"
        targetRevision: main
        path: status-page
        helm:
          valueFiles:
            - values.yaml
      destination:
        server: "https://kubernetes.default.svc"
        namespace: status-page
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML
}

resource "kubectl_manifest" "argocd_self_managed" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: argocd-config
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: "https://github.com/alondudi/status-page-DevOps.git"
        targetRevision: main
        path: argocd-config   # <--- התיקייה החדשה שיצרנו!
      destination:
        server: "https://kubernetes.default.svc"
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML
}

# -----------------------------------------------------------------------------
# 5. ArgoCD Image Updater Application
# -----------------------------------------------------------------------------

resource "kubectl_manifest" "argocd_image_updater" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: argocd-image-updater
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: "https://argoproj.github.io/argo-helm"
        targetRevision: 0.9.1
        chart: argocd-image-updater
        helm:
          values: |
            config:
              registries:
                - name: ECR
                  api_url: https://992382545251.dkr.ecr.us-east-1.amazonaws.com
                  ping: yes
                  credentials: ext:/scripts/ecr-login.sh
                  credsexpire: 10h
      destination:
        server: "https://kubernetes.default.svc"
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML
}
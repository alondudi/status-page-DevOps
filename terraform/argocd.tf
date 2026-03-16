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

# -----------------------------------------------------------------------------
# 3. ArgoCD Application for status-page
# -----------------------------------------------------------------------------

resource "kubectl_manifest" "argocd_app" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: status-page
      namespace: argocd
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
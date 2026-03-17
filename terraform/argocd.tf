# =============================================================================
# ArgoCD — GitOps Continuous Deployment
# Deploys ArgoCD via Helm ONLY (Apps are managed via GitOps/Root App)
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
# 2. ArgoCD Helm Release (The Base Installation)
# -----------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "5.55.0"

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

# -----------------------------------------------------------------------------
# הערה: אם הבלוקים של ה-IAM (ההרשאות ל-AWS של ה-Image Updater שיצרנו אתמול)
# היו בקובץ הזה - תוודא שאתה שומר אותם כאן למטה או מעביר אותם לקובץ iam.tf!
# -----------------------------------------------------------------------------
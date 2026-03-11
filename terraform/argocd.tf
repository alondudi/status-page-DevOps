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

  # --- Server: run insecure (ALB handles TLS) ---
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # --- Server Ingress (ALB) ---
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "alb"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\": 80}\\, {\"HTTPS\": 443}]"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = aws_acm_certificate.main.arn
  }

  set {
    name  = "server.ingress.hosts[0]"
    value = "argocd.statuspage-aa.click"
  }

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.main
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

locals {
  use_github_app = var.github_app_id != ""

  ingress_annotations = {
    "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"     = "ip"
    "alb.ingress.kubernetes.io/group.name"      = var.ingress_group
    "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
    "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80},{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
  }

  # Lets the root app wait for child Applications to become healthy (sync waves).
  application_health_check = <<-LUA
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        if obj.status.health.message ~= nil then
          hs.message = obj.status.health.message
        end
      end
    end
    return hs
  LUA

  argocd_values = {
    global = {
      domain = var.hostname
    }

    configs = {
      params = {
        "server.insecure" = true
      }
      cm = {
        "timeout.reconciliation"                                                                              = "180s"
        "resource.customizations.health.argoproj.io_Application"                                              = local.application_health_check
        "resource.customizations.ignoreDifferences.admissionregistration.k8s.io_MutatingWebhookConfiguration" = "jsonPointers:\n  - /webhooks/0/clientConfig/caBundle\n"
      }
      repositories = {
        karpenter = {
          name      = "karpenter"
          url       = "public.ecr.aws/karpenter"
          type      = "helm"
          enableOCI = "true"
        }
        platform = merge(
          { url = var.repo_url, type = "git" },
          local.use_github_app ? {
            githubAppID             = var.github_app_id
            githubAppInstallationID = var.github_app_installation_id
          } : {}
        )
      }
    }

    controller = {
      replicas = var.high_availability ? 2 : 1
    }

    server = {
      replicas = var.high_availability ? 2 : 1
      ingress = {
        enabled          = true
        ingressClassName = "alb"
        annotations      = local.ingress_annotations
      }
    }

    repoServer = {
      replicas = var.high_availability ? 2 : 1
    }

    dex = {
      enabled = false
    }

    "redis-ha" = {
      enabled = var.high_availability
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  wait             = true
  timeout          = 900

  values = [yamlencode(local.argocd_values)]

  set_sensitive = local.use_github_app ? [{
    name  = "configs.repositories.platform.githubAppPrivateKey"
    value = var.github_app_private_key
  }] : []
}

# AppProjects and the root Application; everything else is pulled from Git.
resource "helm_release" "bootstrap" {
  name      = "argocd-bootstrap"
  namespace = var.namespace
  chart     = "${path.module}/charts/argocd-bootstrap"
  wait      = true

  values = [yamlencode({
    repoURL        = var.repo_url
    targetRevision = var.target_revision
    rootPath       = var.root_path
    values         = var.platform_values
  })]

  depends_on = [helm_release.argocd]
}

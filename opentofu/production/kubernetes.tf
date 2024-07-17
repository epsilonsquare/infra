data "kustomization_build" "argocd" {
  count = var.deploy_kubernetes_resources ? 1 : 0
  path = "${path.module}/../../kube/argocd"
}

resource "kustomization_resource" "argocd0" {
  for_each = coalesce(one(data.kustomization_build.argocd[*].ids_prio[0]), toset([]))
  manifest = one(data.kustomization_build.argocd[*].manifests[each.value])
  depends_on = [module.deploy_nixos]
}

resource "kustomization_resource" "argocd1" {
  for_each = coalesce(one(data.kustomization_build.argocd[*].ids_prio[1]), toset([]))
  manifest = one(data.kustomization_build.argocd[*].manifests[each.value])
  depends_on = [kustomization_resource.argocd0]
}

resource "kustomization_resource" "argocd2" {
  for_each = coalesce(one(data.kustomization_build.argocd[*].ids_prio[2]), toset([]))
  manifest = one(data.kustomization_build.argocd[*].manifests[each.value])
  depends_on = [kustomization_resource.argocd1]
}

resource "tls_private_key" "argocd_infra_repo_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "argocd_chunked_repo_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "kubernetes_secret" "argocd_infra_repo_key" {
  count = var.deploy_kubernetes_resources ? 1 : 0

  metadata {
    name = "infra-repository-ssh-key"
    namespace = "argocd"
  }

  data = {
    key = tls_private_key.argocd_infra_repo_key.private_key_pem
  }

  depends_on = [kustomization_resource.argocd2]
}

resource "kubernetes_secret" "argocd_chunked_repo_key" {
  count = var.deploy_kubernetes_resources ? 1 : 0

  metadata {
    name = "chunked-repository-ssh-key"
    namespace = "argocd"
  }

  data = {
    key = tls_private_key.argocd_chunked_repo_key.private_key_pem
  }

  depends_on = [kustomization_resource.argocd2]
}

resource "github_repository_deploy_key" "argocd_infra_deploy_key" {
  title = "ArgoCD key"
  repository = "infra"
  key = tls_private_key.argocd_infra_repo_key.public_key_openssh
  read_only = true
}

resource "github_repository_deploy_key" "argocd_chunked_deploy_key" {
  title = "ArgoCD key"
  repository = "chunked"
  key = tls_private_key.argocd_chunked_repo_key.public_key_openssh
  read_only = true
}

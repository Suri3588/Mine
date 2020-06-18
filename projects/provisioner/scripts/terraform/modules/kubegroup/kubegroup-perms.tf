provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.kubgrp_aks.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.kubgrp_aks.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.kubgrp_aks.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.kubgrp_aks.kube_admin_config.0.cluster_ca_certificate)
}

resource "kubernetes_service_account" "api-deployment-account" {
  depends_on  = [ azurerm_kubernetes_cluster.kubgrp_aks ]
  metadata {
    name = "api-deployment-account"
  }
}

resource "kubernetes_cluster_role_binding" "cluster-deployer" {
  depends_on  = [ kubernetes_service_account.api-deployment-account ]
  metadata {
    name = "cluster-deployer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "api-deployment-account"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "viewers" {
  depends_on  = [ azurerm_kubernetes_cluster.kubgrp_aks ]
  metadata {
    name = "viewers"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.clusterViewerGuid
  }
}

resource "kubernetes_cluster_role_binding" "admin" {
  depends_on  = [ azurerm_kubernetes_cluster.kubgrp_aks ]
  metadata {
    name = "admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.clusterAdminGuid
  }
}

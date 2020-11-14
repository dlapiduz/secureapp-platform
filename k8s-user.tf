# create eks_developer RBAC Role
resource "kubernetes_role" "eks_developer" {
  metadata {
    name = "eks_developer"
    namespace = "test"
  }

  rule {
    api_groups = ["*"]
    resources  = ["pods", "pods/log", "deployments", "ingresses", "services",
                  "replicasets", "deployments", "namespaces", "resourcequotas"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["*"]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }

  rule {
    api_groups = ["*"]
    resources  = ["pods", "deployments", "services"]
    verbs      = ["create", "delete", "patch", "update", "list"]
  }

  rule {
    api_groups = ["*"]
    resources  = ["pods/portforward"]
    verbs      = ["*"]
  }
}

# RoleBinding for eks_developer:eks_developer
resource "kubernetes_role_binding" "eks_developer" {
  metadata {
    name = "eks_developer"
    namespace = "test"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "eks_developer"
  }

  subject {
    name      = "eks-developer"
    kind      = "User"
    api_group = "rbac.authorization.k8s.io"
  }

}

# CluterRoleBinding for eks_developer:psp
resource "kubernetes_cluster_role_binding" "eks_developer_psp" {
  metadata {
    name = "eks_developer_psp"
  }


 role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "psp:restricted"
  }

  subject {
    name      = "eks-developer"
    kind      = "User"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [ kubernetes_cluster_role.restricted_psp_role ]
}
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.eks_test.id
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks_test.id
}

# Auth to EKS cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}

# create a test namespace
resource "kubernetes_namespace" "test_namespace" {
  metadata {
    annotations = {
      name = "test"
    }
    name = "test"
  }
}

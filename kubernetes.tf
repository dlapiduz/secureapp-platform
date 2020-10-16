# provider "kubernetes" {
#   load_config_file       = "false"
#   host                   = aws_eks_cluster.eks_test.endpoint
#   # token                  = aws_eks_cluster_auth.eks_test.token
#   cluster_ca_certificate = base64decode(aws_eks_cluster.eks_test.certificate_authority.0.data)
# }

# resource "kubernetes_namespace" "my-namespace" {
#   metadata {
#     name = "my-namespace"
#   }
# }
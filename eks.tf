locals {
 cluster_name="eks_test"
}

variable "local_ip" {
  type = string
}

resource "aws_eks_cluster" "eks_test" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster-role.arn

  vpc_config {
    subnet_ids = [aws_subnet.eks_vpc_subnet_public[0].id,
                  aws_subnet.eks_vpc_subnet_public[1].id,
                  aws_subnet.eks_vpc_subnet_private[1].id,
                  aws_subnet.eks_vpc_subnet_private[1].id]

    endpoint_private_access = true
    endpoint_public_access = true
    public_access_cidrs = [var.local_ip]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_key.arn
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks-iam-role-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-iam-role-AmazonEKSVPCResourceController,
    aws_cloudwatch_log_group.eks-log-group
  ]
}

resource "aws_eks_node_group" "ng1" {
  cluster_name    = aws_eks_cluster.eks_test.name
  node_group_name = "ng1"
  node_role_arn   = aws_iam_role.node-role.arn
  subnet_ids      = aws_subnet.eks_vpc_subnet_private[*].id
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  remote_access {
    ec2_ssh_key = "diego"
    source_security_group_ids = [aws_security_group.allow_sg.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks-iam-role-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-iam-role-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-iam-role-AmazonEC2ContainerRegistryReadOnly,
    aws_vpc_endpoint.eks_endpoint,
    aws_vpc_endpoint.eks_s3_endpoint,
  ]
}


resource "aws_cloudwatch_log_group" "eks-log-group" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 7

  # ... potentially other configuration ...
}

output "endpoint" {
  value = aws_eks_cluster.eks_test.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks_test.certificate_authority[0].data
}


# OIDC
locals {
  eks-oidc-thumbprint = "fa20021735418e97db608e18e7be636769f26eef"
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.eks-oidc-thumbprint]
  url             = aws_eks_cluster.eks_test.identity[0].oidc[0].issuer
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "oidc_role" {
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
  name               = "oidc_role"
}
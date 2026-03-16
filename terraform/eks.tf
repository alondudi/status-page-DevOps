resource "aws_eks_cluster" "main" {
  name     = "status-page-cluster-aa"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    security_group_ids      = [aws_security_group.eks_nodes.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true 
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

resource "aws_eks_access_entry" "aviad_access" {
  cluster_name  = aws_eks_cluster.main.name            
  principal_arn = "arn:aws:iam::992382545251:user/aviadbenyaakov" 
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "aviad_admin_policy" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.aviad_access.principal_arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "status-page-nodes-lt-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" 
    http_put_response_hop_limit = 2          
  }

  description = "Launch template for EKS nodes with hop limit 2"
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "status-page-node-group-aa"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = module.vpc.private_subnets
  instance_types  = ["t3.medium"]

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.default_version
  }

  scaling_config {
    desired_size = 2 
    max_size     = 4
    min_size     = 1 
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only
  ]
}
 

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}
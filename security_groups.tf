resource "aws_security_group" "eks_nodes" {
  name        = "status-page-eks-nodes-aa-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "status-page-eks-nodes-aa-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "status-page-rds-aa-sg"
  description = "Allow inbound traffic for Postgres from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow Postgres traffic from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id] 
  }

  tags = {
    Name = "status-page-rds-aa-sg"
  }
}

resource "aws_security_group" "redis" {
  name        = "status-page-redis-aa-sg"
  description = "Allow inbound traffic for Redis from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow Redis traffic from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "status-page-redis-aa-sg"
  }
}
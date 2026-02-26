resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "status-page-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "status-page-db-subnet-group"
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "status-page-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}


resource "aws_db_instance" "postgres" {
  identifier             = "status-page-db-aa"
  engine                 = "postgres"
  engine_version         = "12"           
  instance_class         = "db.t3.micro"  
  allocated_storage      = 20            
  db_name                = "statuspage"
  username               = "dbadmin"

  password               = random_password.db_password.result  
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds.id] 
  skip_final_snapshot    = true 
}


resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "status-page-redis-aa"
  engine               = "redis"
  engine_version       = "6.2" 
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  port                 = 6379
  
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis.id] 
}
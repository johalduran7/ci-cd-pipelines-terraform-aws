# create aurora db mysql type, default version, Production template, DB cluster identifier=database-2, username=admin, cluster storage configuration=standard, burstable classes=db.t3.medium, create an aurora replica or reader node in a different az, don't connect to ec2, ipv4, SG demo-database-aurora, port 3306, no monitoring,  initial database name mydb, backup retention 1 days, 

### get mysql version:
# aws rds describe-db-engine-versions \
#     --engine aurora-mysql \
#     --query "DBEngineVersions[].EngineVersion" \
#     --output text



# Create Aurora MySQL DB Cluster
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "database-2"
  engine                  = "aurora-mysql"            # Aurora MySQL engine
  engine_version          = "8.0.mysql_aurora.3.07.1" # Default Aurora MySQL version (change if needed)
  master_username         = "admin"
  master_password         = "12345678" # Replace with your password
  database_name           = "mydb"
  backup_retention_period = 1
  storage_encrypted       = false # Not required, change to true if you want encryption
  port                    = 3306
  vpc_security_group_ids  = [aws_security_group.aurora_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.aurora_subnet_group.name
  apply_immediately       = true
  skip_final_snapshot     = true
  availability_zones      = ["us-east-1a", "us-east-1b"] # Select different AZs for high availability

  # Tags for organization (Optional)
  tags = {
    Name        = "AuroraMySQLCluster"
    Environment = "Production"
    Terraform   = "yes"
  }
}

# Create an Aurora MySQL DB Instance (Primary Writer)
resource "aws_rds_cluster_instance" "aurora_primary" {
  identifier           = "aurora-primary"
  cluster_identifier   = aws_rds_cluster.aurora_cluster.id
  instance_class       = "db.t3.medium"
  engine               = aws_rds_cluster.aurora_cluster.engine
  engine_version       = aws_rds_cluster.aurora_cluster.engine_version
  publicly_accessible  = true
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name
  availability_zone    = "us-east-1a" # Primary AZ
  apply_immediately    = true
}

# Create Aurora Read Replica (Reader Node in a different AZ)
resource "aws_rds_cluster_instance" "aurora_replica" {
  identifier           = "aurora-replica"
  cluster_identifier   = aws_rds_cluster.aurora_cluster.id
  instance_class       = "db.t3.medium"
  engine               = aws_rds_cluster.aurora_cluster.engine
  engine_version       = aws_rds_cluster.aurora_cluster.engine_version
  publicly_accessible  = true
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name
  availability_zone    = "us-east-1b" # Reader in a different AZ
  apply_immediately    = true
}

# Security Group for Aurora
resource "aws_security_group" "aurora_sg" {
  name        = "demo-database-aurora"
  description = "Security group for Aurora MySQL"

  # Inbound rule to allow MySQL (3306) from any IP (public access)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public access, secure this by limiting IPs if needed
  }

  # Egress rule (Allow all outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "AuroraDBSecurityGroup"
    Terraform = "yes"
  }
}
variable "vpc_id" {
  type    = string
  default = "vpc-53cd6b2e"

}

data "aws_subnets" "subnets_aurora" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# Create a DB Subnet Group for Aurora
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "aurora-subnet-group"
  subnet_ids = toset(data.aws_subnets.subnets_aurora.ids) # Replace with your VPC subnets

  tags = {
    Name      = "AuroraDBSubnetGroup"
    Terraform = "yes"
  }
}

# Outputs for convenience
output "db_cluster_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}

output "db_reader_endpoint" {
  value = aws_rds_cluster.aurora_cluster.reader_endpoint
}

output "db_cluster_security_group" {
  value = aws_security_group.aurora_sg.id
}

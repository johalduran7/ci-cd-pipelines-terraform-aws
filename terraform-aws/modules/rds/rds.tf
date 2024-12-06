#Create an RDS database type mysql free tier option, single DB instance, template Production, size Burstable classes db.t3.micro, storage type= gp2, 20 GB, Storage autoscaling=1000GB, don't connect with EC2, public access, create SG for this RDS db, Password authentication. no monitoring, name of the db= mydb, backup retention period 7 days, Maintenance window=no preference

resource "aws_db_instance" "mydb" {
  # Database Engine and version
  engine                     = "mysql"
  instance_class             = "db.t3.micro"
  allocated_storage          = 20
  max_allocated_storage      = 1000
  storage_type               = "gp2"
  db_name                    = "mydb"
  username                   = "admin"    # Modify as needed
  password                   = "12345678" # Modify as needed
  publicly_accessible        = true
  backup_retention_period    = 7
  skip_final_snapshot        = true
  apply_immediately          = true
  multi_az                   = false
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  deletion_protection        = false


  # Free tier template option with no performance insights or monitoring
  performance_insights_enabled = false

  # Security group creation for RDS instance
  vpc_security_group_ids = [aws_security_group.rds_sg_mysql.id]

  # Tags for organization (Optional)
  tags = {
    Name        = "MyDBInstance"
    Environment = "Production"
    Terraform   = "yes"
  }
}

resource "aws_security_group" "rds_sg_mysql" {
  name        = "rds_sg_mysql"
  description = "Allow MySQL inbound traffic"

  # Allow public access to MySQL (port 3306)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public access
  }

  # Egress rule - Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "rds_sg_mysql"
    Environment = "Production"
    Terraform   = "yes"
  }
}

output "db_endpoint" {
  value = aws_db_instance.mydb.endpoint
}

output "db_security_group" {
  value = aws_security_group.rds_sg_mysql.id
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

# ── Security Group ────────────────────────────────────────────
resource "aws_security_group" "jenkins" {
  name        = "${local.name_prefix}-jenkins-sg"
  description = "Security perimeter firewall for Jenkins and SonarQube hosts"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH administrative access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Jenkins web UI access dashboard"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube code analysis dashboard"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP standard egress response hook"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS secure handshake verification"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow unrestricted outbound calls to update mirrors"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { 
    Name        = "${local.name_prefix}-jenkins-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── Key Pair ──────────────────────────────────────────────────
resource "aws_key_pair" "jenkins" {
  key_name   = "${local.name_prefix}-jenkins-key"
  public_key = file("/home/ubuntu/.ssh/id_rsa.pub")
}

# ── Jenkins EC2 Instance ──────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.jenkins.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  user_data = templatefile("${path.module}/install_tools.sh", {
    region           = var.aws_region
    backup_s3_bucket = var.backup_s3_bucket
    environment      = var.environment
  })

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${local.name_prefix}-jenkins-server"
    Environment = var.environment
    Role        = "cicd-server"
    Project     = var.project_name
  }
}

# ── Persistent EBS Volume for Jenkins Data ────────────────────
resource "aws_ebs_volume" "jenkins_data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "${local.name_prefix}-jenkins-data"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ── Attach EBS to Jenkins EC2 ─────────────────────────────────
resource "aws_volume_attachment" "jenkins_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.jenkins_data.id
  instance_id = aws_instance.jenkins.id
}

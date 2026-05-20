# ─────────────────────────────────────────────
# VM1: API Gateway (iii Engine + Nginx)
# Public subnet — this is the only internet-facing VM
# ─────────────────────────────────────────────
resource "aws_instance" "vm1_api_gateway" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.api_gateway.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data/vm1.sh.tpl", {
    github_repo    = var.github_repo
    dockerhub_user = var.dockerhub_user
  })

  tags = { Name = "${var.project_name}-vm1-api-gateway" }
}

# ─────────────────────────────────────────────
# VM2: Caller Worker (TypeScript)
# Private subnet — NOT reachable from internet
# ─────────────────────────────────────────────
resource "aws_instance" "vm2_caller" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.workers.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # Terraform resolves vm1's private IP automatically — no manual copy-paste
  user_data = templatefile("${path.module}/user-data/worker.sh.tpl", {
    github_repo    = var.github_repo
    dockerhub_user = var.dockerhub_user
    engine_ip      = aws_instance.vm1_api_gateway.private_ip
    compose_file   = "docker-compose.vm2.yml"
    worker_name    = "caller-worker"
  })

  tags = { Name = "${var.project_name}-vm2-caller-worker" }

  depends_on = [aws_instance.vm1_api_gateway, aws_nat_gateway.nat]
}

# ─────────────────────────────────────────────
# VM3: Inference Worker (Python + Qwen3 model)
# Private subnet — NOT reachable from internet
# ─────────────────────────────────────────────
resource "aws_instance" "vm3_inference" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "c7i-flex.large" # 4GB RAM for model inference
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.workers.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 30 # Extra disk for the ~2GB Docker image
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data/worker.sh.tpl", {
    github_repo    = var.github_repo
    dockerhub_user = var.dockerhub_user
    engine_ip      = aws_instance.vm1_api_gateway.private_ip
    compose_file   = "docker-compose.vm3.yml"
    worker_name    = "inference-worker"
  })

  tags = { Name = "${var.project_name}-vm3-inference-worker" }

  depends_on = [aws_instance.vm1_api_gateway, aws_nat_gateway.nat]
}

# ─────────────────────────────────────────────
# SG: API Gateway (VM1 — public-facing)
# ─────────────────────────────────────────────
resource "aws_security_group" "api_gateway" {
  name        = "${var.project_name}-api-gateway-sg"
  description = "API Gateway: HTTP from internet, SSH from admin IP"
  vpc_id      = aws_vpc.main.id

  # HTTP from anywhere (nginx)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH from your IP only
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # RPC WebSocket from private subnet (workers connect here)
  ingress {
    description = "iii RPC WebSocket from workers"
    from_port   = 49134
    to_port     = 49134
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-api-gateway-sg" }
}

# ─────────────────────────────────────────────
# SG: Workers (VM2, VM3 — private subnet only)
# ─────────────────────────────────────────────
resource "aws_security_group" "workers" {
  name        = "${var.project_name}-workers-sg"
  description = "Workers: SSH from API gateway only, outbound for docker pull + RPC"
  vpc_id      = aws_vpc.main.id

  # SSH from API gateway (for debugging via jump host)
  ingress {
    description     = "SSH from API gateway"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  # All outbound (docker pull from Hub, RPC to engine)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-workers-sg" }
}

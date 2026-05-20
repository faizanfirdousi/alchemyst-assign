# Distributed Inference System — DevOps Assignment

A production-grade deployment of a distributed SLM (Small Language Model) inference system across multiple AWS EC2 instances. The system runs a **Qwen3-0.6B** model behind a worker mesh orchestrated by the [iii framework](https://iii.dev), exposed as a JSON HTTP API through an Nginx reverse proxy.

## Architecture

![Architecture Diagram](./architecture-al.png)

### Request Flow

![Request Flow](./networkflow-al.png)

### Component Overview

| Component            | VM  | Subnet  | Language    | Function                                           |
| -------------------- | --- | ------- | ----------- | -------------------------------------------------- |
| **iii Engine**       | VM1 | Public  | Rust binary | Orchestrates workers, serves HTTP API              |
| **Nginx**            | VM1 | Public  | —           | Reverse proxy with rate limiting, security headers |
| **Caller Worker**    | VM2 | Private | TypeScript  | Routes HTTP requests → inference RPC calls         |
| **Inference Worker** | VM3 | Private | Python      | Loads Qwen3-0.6B model, runs inference             |

### Network Security

- **VM1** is the only public-facing instance (port 80 HTTP, port 22 SSH from admin IP)
- **VM2/VM3** are in a private subnet — **NOT reachable from the internet**
- Workers connect to the engine via WebSocket RPC over the VPC private network (`ws://10.0.1.x:49134`)
- NAT Gateway provides outbound-only internet access for VM2/VM3 (docker pull, apt-get)

---

## API Documentation

### Health Check

```bash
curl http://<PUBLIC_IP>/health
```

```json
{ "status": "ok" }
```

### Run Inference

```bash
curl -X POST http://<PUBLIC_IP>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Explain quantum entanglement in simple terms."}
    ]
  }'
```

**Response:**

```json
{
  "result": {
    "response": "Quantum entanglement is a phenomenon where two particles become linked...",
    "success": "You've connected two workers and they're interoperating seamlessly..."
  }
}
```

### Request Schema

| Field                | Type   | Required | Description                               |
| -------------------- | ------ | -------- | ----------------------------------------- |
| `messages`           | Array  | Yes      | Chat messages in OpenAI-compatible format |
| `messages[].role`    | String | Yes      | `"user"`, `"assistant"`, or `"system"`    |
| `messages[].content` | String | Yes      | Message content                           |

---

## Deployment

### Prerequisites

- AWS account with credentials configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Docker](https://get.docker.com) (for building images locally)
- An EC2 key pair created in `ap-south-1`

### Deploy from Scratch

```bash
# 1. Clone the repo
git clone https://github.com/faizanfirdousi/alchemyst-assign.git
cd alchemyst-assign

# 2. Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   key_name = "your-ec2-keypair"
#   my_ip    = "YOUR_PUBLIC_IP/32"    ← run: curl -s ifconfig.me

# 3. Deploy
terraform init
terraform plan     # Review what will be created
terraform apply    # Create everything (~3-5 minutes)

# 4. Wait ~2-3 minutes for user-data scripts to complete, then test:
curl http://$(terraform output -raw api_gateway_public_ip)/health
curl -X POST http://$(terraform output -raw api_gateway_public_ip)/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}]}'

# 5. Tear down when done
terraform destroy
```

### What Terraform Creates

| Resource         | Count | Purpose                                              |
| ---------------- | ----- | ---------------------------------------------------- |
| VPC              | 1     | Isolated network (`10.0.0.0/16`)                     |
| Public Subnet    | 1     | Hosts VM1 (`10.0.1.0/24`)                            |
| Private Subnet   | 1     | Hosts VM2, VM3 (`10.0.2.0/24`)                       |
| Internet Gateway | 1     | Public subnet → internet                             |
| NAT Gateway      | 1     | Private subnet → internet (outbound only)            |
| Security Groups  | 2     | API gateway (public) + Workers (private)             |
| EC2 Instances    | 3     | VM1 (t3.small), VM2 (t3.small), VM3 (c7i-flex.large) |

---

## Docker Images

All services are containerized and pre-built on Docker Hub:

| Image                                 | Size   | Contents                                       |
| ------------------------------------- | ------ | ---------------------------------------------- |
| `faizanfirdousi/iii-engine`           | 258 MB | iii engine binary + config                     |
| `faizanfirdousi/iii-caller-worker`    | 305 MB | Node.js 20 + TypeScript worker                 |
| `faizanfirdousi/iii-inference-worker` | 2.1 GB | Python 3.11 + PyTorch (CPU) + Qwen3-0.6B model |

### Rebuild Images (optional)

```bash
# From the repo root
docker build -f docker/engine/Dockerfile -t faizanfirdousi/iii-engine:latest .
docker build -f docker/caller-worker/Dockerfile -t faizanfirdousi/iii-caller-worker:latest .
docker build -f docker/inference-worker/Dockerfile -t faizanfirdousi/iii-inference-worker:latest .

docker push faizanfirdousi/iii-engine:latest
docker push faizanfirdousi/iii-caller-worker:latest
docker push faizanfirdousi/iii-inference-worker:latest
```

---

## Repository Structure

```
.
├── config.yaml                 # iii engine configuration
├── iii.lock                    # Worker version lock
├── workers/
│   ├── caller-worker/          # TypeScript — routes HTTP → RPC
│   │   ├── src/worker.ts
│   │   └── package.json
│   └── inference-worker/       # Python — runs Qwen3-0.6B model
│       ├── inference_worker.py
│       └── requirements.txt
├── docker/
│   ├── engine/
│   │   ├── Dockerfile          # iii engine container
│   │   └── nginx.conf          # Nginx: rate limiting, security headers, health check
│   ├── caller-worker/
│   │   └── Dockerfile          # Node.js 20 container
│   └── inference-worker/
│       └── Dockerfile          # Python 3.11 + model pre-downloaded
├── docker-compose.vm1.yml      # VM1: engine + nginx (public subnet)
├── docker-compose.vm2.yml      # VM2: caller worker (private subnet)
├── docker-compose.vm3.yml      # VM3: inference worker (private subnet)
├── terraform/
│   ├── main.tf                 # Provider + AMI data source
│   ├── variables.tf            # Configurable inputs
│   ├── vpc.tf                  # VPC, subnets, IGW, NAT, route tables
│   ├── security_groups.tf      # Firewall rules
│   ├── ec2.tf                  # 3 EC2 instances + user-data
│   ├── outputs.tf              # Public IP + curl commands
│   ├── terraform.tfvars.example
│   └── user-data/
│       ├── vm1.sh.tpl          # VM1 bootstrap (15 lines)
│       └── worker.sh.tpl       # VM2/VM3 bootstrap (ENGINE_IP injected)
└── README.md
```

---

## Production Hardening

If this system were going to production, the following changes would be made:

### Security

- **TLS termination** — Add an ALB with ACM certificate for HTTPS, or use Let's Encrypt with Certbot on Nginx. All traffic is currently HTTP.
- **Authentication** — Add API key or JWT authentication to the inference endpoint. Currently the API is open to anyone.
- **Secrets management** — Use AWS Secrets Manager or SSM Parameter Store instead of environment variables for sensitive configuration.
- **Container scanning** — Run Trivy or Snyk on Docker images in CI to catch CVEs before deployment.
- **SSH hardening** — Replace SSH key access with AWS SSM Session Manager (no open port 22, no key management, full audit trail).

### Reliability

- **Health check integration** — Wire the `/health` endpoint into an ALB target group with automatic unhealthy instance replacement.
- **Auto-restart** — Docker `restart: unless-stopped` handles container crashes, but instance-level failures need an ASG (Auto Scaling Group) with min=1.
- **Persistent state** — The iii engine's state store (`state_store.db`) is on an ephemeral Docker volume. Move to EBS or RDS for durability.
- **Logging** — Ship container logs to CloudWatch Logs or ELK via Fluent Bit. Currently logs are only visible via `docker logs`.
- **Monitoring** — Add Prometheus + Grafana for metrics (request latency, model inference time, error rate). The iii engine already exposes OpenTelemetry data.

### Performance

- **Connection pooling** — Nginx `upstream` with keepalive connections to reduce TCP overhead.
- **Response caching** — Cache identical prompts in Redis for repeated queries (same input → same output for temperature=0).
- **Request queuing** — Add SQS between the HTTP layer and inference workers to handle burst traffic without dropping requests.

---

## Scaling to 100x Larger Models

If the model were 100x larger (e.g., 60B parameters instead of 600M):

### Compute

- **GPU instances required** — A 60B model in FP16 needs ~120GB VRAM. Use `p4d.24xlarge` (8x A100 80GB) or `p5.48xlarge` (8x H100) with tensor parallelism across GPUs.
- **Model sharding** — Use frameworks like vLLM, TGI (Text Generation Inference), or DeepSpeed to shard the model across multiple GPUs. Single-GPU won't fit.
- **Spot instances** — For non-latency-critical inference, use Spot Instances at 60-90% discount with graceful fallback to on-demand.

### Architecture

- **Queue-based inference** — Replace synchronous RPC with an SQS/Redis queue. Clients submit requests and poll for results. This decouples the API tier from inference latency (which could be 10-30s for a 60B model).
- **Horizontal scaling** — Run multiple inference worker replicas behind the iii engine. The engine's RPC mesh already supports multiple workers registering the same function — it load-balances across them.
- **Model caching** — Store model weights on EFS (shared filesystem) instead of baking into Docker images. A 120GB Docker image is impractical to push/pull.
- **Inference optimization** — Use quantization (GPTQ, AWQ) to reduce memory footprint by 2-4x. A 60B model in 4-bit quantization fits in ~30GB VRAM (one A100).

### Infrastructure

- **Multi-AZ** — Deploy across multiple availability zones for high availability.
- **CDN** — Put CloudFront in front of the API for global latency reduction and DDoS protection.
- **Autoscaling** — Use Kubernetes (EKS) with KEDA for GPU-aware autoscaling based on queue depth.
- **Cost optimization** — Reserved Instances for baseline capacity + Spot for burst. Monitor with AWS Cost Explorer and set billing alerts.

FROM python:3.11-slim

# System deps for torch / transformers
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first for layer caching
COPY workers/inference-worker/requirements.txt ./

# Install Python deps (CPU-only torch saves ~1.5GB)
RUN pip install --no-cache-dir \
        torch --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY workers/inference-worker/inference_worker.py ./

# Pre-download model at build time so first inference is instant
# Uses the same model as inference_worker.py (Qwen3-0.6B GGUF Q8)
RUN python -c "\
from transformers import AutoModelForCausalLM, AutoTokenizer; \
model_id = 'Qwen/Qwen3-0.6B-GGUF'; \
gguf_file = 'Qwen3-0.6B-Q8_0.gguf'; \
print('Downloading tokenizer...'); \
AutoTokenizer.from_pretrained(model_id, gguf_file=gguf_file); \
print('Downloading model...'); \
AutoModelForCausalLM.from_pretrained(model_id, gguf_file=gguf_file); \
print('Model cached in image.')"

# III_URL is injected at runtime via docker-compose env
ENV III_URL=ws://localhost:49134

CMD ["python", "inference_worker.py"]

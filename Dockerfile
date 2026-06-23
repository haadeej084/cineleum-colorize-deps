# Cineleum colorize — deps-image. Bakt de geverifieerde stack in zodat de
# vast-worker bij cold-start GEEN 17-min pip-install van torch hoeft te doen.
# Het model blijft buiten de image (HF + hf_transfer) — alleen libs hier.
#
# torch cu128-wheels zijn self-contained (bundelen CUDA/cuDNN), dus een slanke
# python-base volstaat; de host-driver (>=12.8 op de vast-4090's) doet de rest.
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1

# opencv-python-headless heeft GEEN libGL nodig; libglib2.0-0 voor de zekerheid.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 git wget curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Geverifieerde stack (zelfde versies als onstart_serverless.sh, getest L40S/5090).
RUN pip install --upgrade pip && \
    pip install hf_transfer huggingface_hub && \
    pip install torch==2.11.0+cu128 torchvision==0.26.0+cu128 \
        --index-url https://download.pytorch.org/whl/cu128 && \
    pip install "diffusers>=0.32.0" "transformers>=4.49.0,<5.0" "accelerate>=0.30.0" \
        torchao==0.17.0 sentencepiece protobuf "Pillow>=10.0" \
        opencv-python-headless numpy

# Sanity: importeren mag niet falen in de build.
RUN python -c "import torch, torchao, diffusers, cv2, transformers; print('deps OK', torch.__version__)"

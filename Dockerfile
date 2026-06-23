# Cineleum colorize — deps-image. Bakt de geverifieerde stack in zodat de
# vast-worker bij cold-start GEEN 17-min pip-install van torch hoeft te doen.
# Het model blijft buiten de image (HF + hf_transfer) — alleen libs hier.
#
# BELANGRIJK: bouw op de pytorch-base die vast's onstart-mechanisme kent (v6 werkte
# hierop). Een kale python-slim-base mist de shell-entrypoint die vast nodig heeft om
# --onstart-cmd via bash te draaien → onstart werd als ruwe binary ge-exec't (faal).
# torch 2.11+cu128 wordt over de base-torch 2.4 geïnstalleerd (groter image, maar werkt).
FROM pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime

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

# KERN-FIX: vast zet de --onstart-cmd als container-command en exec't 'm DIRECT als
# argv[0] (geen shell, geen entrypoint-wrap — vast negeert de image-ENTRYPOINT). Een
# multi-statement string faalt dus met 'no such file'. Oplossing: bak een uitvoerbaar
# bootstrap-script IN de image en zet --onstart-cmd op dát pad (één geldig executable).
RUN printf '%s\n' \
    '#!/bin/bash' \
    'export HF_HUB_ENABLE_HF_TRANSFER=1' \
    'huggingface-cli download HaaDeej/cineleum-colorize-worker onstart_serverless.sh --local-dir /root --token "$HF_TOKEN" >/dev/null 2>&1' \
    'exec bash /root/onstart_serverless.sh' \
    > /usr/local/bin/cineleum-bootstrap \
 && chmod +x /usr/local/bin/cineleum-bootstrap

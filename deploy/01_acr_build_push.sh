#!/usr/bin/env bash
# LAB 10-A — build the image and push it to Azure Container Registry.
# Uses `az acr build` so the image is built in the cloud (no local Docker needed).
set -euo pipefail
cd "$(dirname "$0")/.."
source deploy/00_env.sh

# Create the registry once (idempotent). Basic tier is fine for the lab.
az group create --name "$RG" --location "$LOCATION" -o none
az acr show --name "$ACR" -o none 2>/dev/null || \
  az acr create --name "$ACR" --resource-group "$RG" --sku Basic --admin-enabled true -o none

echo "Building $IMAGE in ACR (cloud build)..."
az acr build --registry "$ACR" --image "${IMAGE_REPO}:${TAG}" --file Dockerfile . -o table

echo "Pushed: $IMAGE"
echo "Tip: also tag a moving 'latest' if you want:  az acr import / az acr build --image ${IMAGE_REPO}:latest"

#!/usr/bin/env bash
# Shared variables for all deploy scripts.  source ./00_env.sh
# Change these to your own names (ACR name must be globally unique, lowercase).

export RG="rg-lab10-agent"
export LOCATION="eastus"
export ACR="acrlab10vrl"                       # -> acrlab10vrl.azurecr.io
export ACA_ENV="cae-lab10"                     # Container Apps environment
export APP="bank-triage-agent"                 # the Container App name
export IMAGE_REPO="bank-triage-agent"          # repo inside ACR
export APP_INSIGHTS="appi-lab10"               # reuse an existing one if you have it

# Image tag is usually the git sha in CI; default to 'local' for manual runs.
export TAG="${TAG:-local}"
export IMAGE="${ACR}.azurecr.io/${IMAGE_REPO}:${TAG}"

echo "Env loaded: RG=$RG APP=$APP IMAGE=$IMAGE"

#!/usr/bin/env bash
# LAB 10-C — blue/green promote with an EVAL GATE.
# 1) Deploy the new image as a GREEN revision at 0% traffic (users stay on BLUE).
# 2) Smoke-test + run the eval gate against GREEN's own URL.
# 3) Only if the gate PASSES, shift 100% traffic BLUE -> GREEN.
# If the gate fails, the script exits non-zero and traffic never moves.
set -euo pipefail
cd "$(dirname "$0")/.."
source deploy/00_env.sh

active_by_age() {  # $1 = index (0 = newest active revision)
  az containerapp revision list --name "$APP" --resource-group "$RG" \
    --query "reverse(sort_by([?properties.active],&properties.createdTime))[$1].name" -o tsv
}

# BLUE = the revision currently serving, captured BEFORE we create green.
BLUE=$(active_by_age 0)
echo "BLUE (current): $BLUE"

# Create GREEN revision from the new image, holding it at 0% traffic.
GREEN="${APP}--v-${TAG}"
echo "Deploying GREEN revision $GREEN at 0% traffic..."
az containerapp update --name "$APP" --resource-group "$RG" \
  --image "$IMAGE" --revision-suffix "v-${TAG}" \
  --set-env-vars APP_VERSION="$TAG" GIT_SHA="$TAG" -o none
az containerapp ingress traffic set --name "$APP" --resource-group "$RG" \
  --revision-weight "${BLUE}=100" "${GREEN}=0" -o table

# GREEN's direct URL (revision-scoped FQDN) so we can test it in isolation.
GREEN_FQDN=$(az containerapp revision show --name "$APP" --resource-group "$RG" \
  --revision "$GREEN" --query properties.fqdn -o tsv)
echo "GREEN URL: https://${GREEN_FQDN}"

echo "== Smoke test GREEN =="
python scripts/smoke_test.py --url "https://${GREEN_FQDN}"

echo "== EVAL GATE against GREEN =="
python eval/eval_gate.py --url "https://${GREEN_FQDN}"   # exits non-zero -> set -e stops here

echo "Gate PASSED — shifting 100% traffic to GREEN."
az containerapp ingress traffic set --name "$APP" --resource-group "$RG" \
  --revision-weight "${GREEN}=100" "${BLUE}=0" -o table

echo "Promoted $GREEN to production. Previous revision $BLUE kept for instant rollback."

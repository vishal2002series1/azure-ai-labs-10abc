# Lab 10 — Container Apps Deploy · CI/CD · LLMOps (Capstone)

Take the agent to production: **containerise** it, push to **Azure Container Registry**,
deploy to **Azure Container Apps** with auto-scaling + health probes, and wire a
**GitHub Actions blue/green pipeline with an eval gate** that blocks bad deploys —
plus a rehearsed **02:00 SEV-1 rollback runbook**.

Scenario: a bank's transaction-triage agent must go live with a rollback runbook and
an eval gate. The app is a small FastAPI service whose decisions come from a
**versioned policy/prompt**; a bad policy change is what the eval gate must catch.

## Files

| Path | Role |
|------|------|
| `app/main.py` | FastAPI service: `/health` `/ready` `/decide` `/version` `/modelcard` |
| `app/agent.py` | The triage decision logic (approve / review / block) |
| `app/policies/policy_v1.json` | Good production policy (the "prompt") |
| `app/policies/policy_v2_bad.json` | Regressed policy — the 02:00 bad change |
| `Dockerfile` / `.dockerignore` | Container image (non-root, healthcheck) |
| `app/requirements.txt` | Container **runtime** deps (kept tiny) |
| `requirements-dev.txt` | Local/offline deps = runtime + `httpx` (needed by the gate/smoke test) |
| `eval/eval_gate.py` + `golden_set.json` | **The gate** that blocks bad deploys |
| `scripts/model_card.py` | LLMOps model-card automation |
| `scripts/smoke_test.py` | Post-deploy sanity check |
| `deploy/00_env.sh` | Shared variables (edit these) |
| `deploy/01_acr_build_push.sh` | **Lab 10-A** build + push to ACR |
| `deploy/02_deploy_containerapp.sh` + `containerapp.yaml` | **Lab 10-B** deploy + probes + autoscale |
| `deploy/03_bluegreen_promote.sh` | **Lab 10-C** blue/green + eval gate |
| `deploy/04_rollback.sh` | **SEV-1** rollback (the 02:00 action) |
| `.github/workflows/deploy.yml` | CI/CD pipeline |

## Try it offline (no Docker, no Azure)

```bash
# create an isolated virtualenv (Python 3.12) and install deps
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt            # app deps + httpx (for the gate/smoke test)

# 1) run the agent locally
uvicorn main:app --app-dir app --port 8000     # then open http://localhost:8000/health

# 2) the eval gate on the GOOD policy -> PASS (exit 0)
python eval/eval_gate.py

# 3) the eval gate on the BAD policy -> FAIL (exit 1) — the deploy would be blocked
AGENT_POLICY=app/policies/policy_v2_bad.json python eval/eval_gate.py

# 4) smoke test + model card
python scripts/smoke_test.py
python scripts/model_card.py --app-version 1.4.0 --git-sha $(git rev-parse --short HEAD) \
  --policy app/policies/policy_v1.json --eval-passed 12 --eval-total 12
```

## Publish to GitHub (needed before CI/CD)

The `.github/workflows/deploy.yml` pipeline runs from your own repo, so publish the lab first.
GitHub rejects pushing files under `.github/workflows/` unless the `gh` token carries the
`workflow` scope — grant it, then push. Replace `<your-github-id>` with your account.

```bash
# 1) create the repo on GitHub (public) under your account
gh repo create <your-github-id>/azure-ai-labs-10abc --public --source . --remote origin
#    (or create it in the GitHub UI, then:
#     git init -b main && git remote add origin \
#       https://github.com/<your-github-id>/azure-ai-labs-10abc.git)

# 2) point gh at the account that owns the repo
gh auth switch --user <your-github-id>

# 3) grant the token the 'workflow' scope (needed for .github/workflows/*)
#    interactive: opens a browser / device-code prompt
gh auth refresh -h github.com -u <your-github-id> -s workflow

# 4) commit and push the CI/CD workflow
git add .github/workflows/deploy.yml
git commit -m "ci: add Container Apps blue/green deploy workflow"
git push -u origin main
```

> If the push is rejected with *"refusing to allow an OAuth App to create or update workflow …
> without `workflow` scope"*, step 3 was skipped — run it and push again.

**CI/CD is opt-in for Azure.** On every push the `eval-precheck` job runs the eval gate. The
`build-deploy-promote` job only runs when the repo **variable** `AZURE_ENABLED == 'true'` and the
three OIDC secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) are set —
otherwise it's skipped and the pipeline stays green. See `Lab10_Azure_Setup_Steps.docx` §6.2 for
exactly where to add the secrets and the `AZURE_ENABLED` variable.

## On Azure

**First, set your own values.** Copy the template to `.env` and edit it — do **not** edit
`deploy/00_env.sh`. `.env` is git-ignored, so your resource-group name and other values stay
out of the repo. Set `RG` to the **existing** resource group already created under your learner
account (`az group list -o table`); `00_env.sh` loads `.env` automatically.

```bash
cp .env.example .env
# then edit .env — at minimum set RG (your existing learner RG) and ACR (globally unique, lowercase)
$EDITOR .env
```

```bash
source deploy/00_env.sh                # loads .env, then falls back to defaults for anything unset
TAG=$(git rev-parse --short HEAD)
./deploy/01_acr_build_push.sh          # Lab 10-A
./deploy/02_deploy_containerapp.sh     # Lab 10-B
./deploy/03_bluegreen_promote.sh       # Lab 10-C (eval gate decides)
./deploy/04_rollback.sh                # SEV-1 rollback drill
```

See `Lab10_Azure_Setup_Steps.docx` (setup), `Lab10_Outcomes_Interpretation.docx`
(how to read what happens), and `Lab10_Rollback_Runbook.xlsx` (the 02:00 runbook).

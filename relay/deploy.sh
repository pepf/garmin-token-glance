#!/usr/bin/env bash
# Deploys the relay. Account, project, bucket and token come from ~/.claude/token-glance/env
# and are pinned here, so the gcloud default account can never be the target.
# --format=none on deploy: gcloud otherwise prints the TOKEN env var.
set -euo pipefail

source ~/.claude/token-glance/env
: "${TOKEN:?TOKEN missing from ~/.claude/token-glance/env}"
: "${GCP_ACCOUNT:?GCP_ACCOUNT missing from ~/.claude/token-glance/env}"
: "${GCP_PROJECT:?GCP_PROJECT missing from ~/.claude/token-glance/env}"
: "${GCP_SERVICE_ACCOUNT:?GCP_SERVICE_ACCOUNT missing from ~/.claude/token-glance/env}"
: "${GCP_BUCKET:?GCP_BUCKET missing from ~/.claude/token-glance/env}"
export CLOUDSDK_CORE_ACCOUNT="$GCP_ACCOUNT"
export CLOUDSDK_CORE_PROJECT="$GCP_PROJECT"
REGION=europe-west4
NAME=usage-relay

cd "$(dirname "$0")"
envfile=$(mktemp)
trap 'rm -f "$envfile"' EXIT
printf 'TOKEN: "%s"\nBUCKET: "%s"\n' "$TOKEN" "$GCP_BUCKET" > "$envfile"

gcloud functions deploy "$NAME" \
  --gen2 --region="$REGION" --runtime=nodejs22 --source=. --entry-point=relay \
  --trigger-http --allow-unauthenticated \
  --service-account="$GCP_SERVICE_ACCOUNT" \
  --memory=1Gi --cpu=1 --timeout=60s --min-instances=0 --max-instances=2 \
  --set-secrets=CLAUDE_CODE_OAUTH_TOKEN=claude-token:latest \
  --env-vars-file="$envfile" --format=none

gcloud functions describe "$NAME" --gen2 --region="$REGION" --format='value(serviceConfig.uri)'

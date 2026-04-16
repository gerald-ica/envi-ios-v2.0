#!/usr/bin/env bash
# provision-secrets.sh
#
# Idempotent provisioning of the 11 staging OAuth secrets required by
# Phase 06-02. The script:
#   1. Creates each secret (ignores "already exists").
#   2. Grants `roles/secretmanager.secretAccessor` to the Functions runtime
#      service account.
#   3. Does NOT write secret values — rotation is a human gate. Follow
#      docs/ops/secret-rotation-checklist.md to populate versions.
#
# Usage:
#   ./scripts/provision-secrets.sh \
#       --project envi-by-informal-staging \
#       --env staging \
#       --service-account <functions-sa-email>
#
# Required:
#   gcloud CLI authenticated with Secret Manager Admin + IAM Admin on the
#   target project.
#
# Safe to re-run. Exits non-zero only on hard failures (missing gcloud,
# permission denied, invalid args).

set -euo pipefail

PROJECT_ID=""
ENV_NAME="staging"
SERVICE_ACCOUNT=""

usage() {
  cat <<EOF
Usage: $0 --project <gcp-project-id> [--env staging|prod] [--service-account <sa-email>]

Options:
  --project <id>           Required. GCP project id (e.g. envi-by-informal-staging).
  --env <name>             Optional. Defaults to "staging". Drives the secret
                           name prefix (staging-*, prod-*).
  --service-account <sa>   Optional but recommended. Functions runtime SA to
                           grant secretmanager.secretAccessor on every secret.
                           If omitted, script creates/verifies secrets only.
  -h, --help               Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_ID="$2"; shift 2 ;;
    --env) ENV_NAME="$2"; shift 2 ;;
    --service-account) SERVICE_ACCOUNT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$PROJECT_ID" ]]; then
  echo "ERROR: --project is required"; usage; exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud CLI not found on PATH"; exit 1
fi

# Canonical list of secret names. Must stay in sync with
# functions/src/lib/secrets.ts STAGING_SECRET_NAMES.
STAGING_SECRETS=(
  "staging-tiktok-sandbox-client-secret"
  "staging-x-oauth1-consumer-secret"
  "staging-x-oauth1-access-token-secret"
  "staging-x-bearer-token"
  "staging-x-oauth2-client-secret"
  "staging-meta-app-secret"
  "staging-envi-threads-app-secret"
  "staging-threads-app-secret"
  "staging-instagram-app-secret"
  "staging-instagram-client-token"
  "staging-linkedin-primary-client-secret"
)

PROD_SECRETS=(
  "prod-tiktok-client-secret"
  "prod-x-oauth1-consumer-secret"
  "prod-x-oauth1-access-token-secret"
  "prod-x-bearer-token"
  "prod-x-oauth2-client-secret"
  "prod-meta-app-secret"
  "prod-envi-threads-app-secret"
  "prod-threads-app-secret"
  "prod-instagram-app-secret"
  "prod-instagram-client-token"
  "prod-linkedin-primary-client-secret"
)

if [[ "$ENV_NAME" == "staging" ]]; then
  SECRETS=("${STAGING_SECRETS[@]}")
elif [[ "$ENV_NAME" == "prod" ]]; then
  SECRETS=("${PROD_SECRETS[@]}")
else
  echo "ERROR: --env must be staging or prod"; exit 1
fi

echo "Project:          $PROJECT_ID"
echo "Environment:      $ENV_NAME"
echo "Service account:  ${SERVICE_ACCOUNT:-(skipped)}"
echo "Secrets to ensure: ${#SECRETS[@]}"
echo ""

gcloud config set project "$PROJECT_ID" >/dev/null

# Enable API once (idempotent).
gcloud services enable secretmanager.googleapis.com --project "$PROJECT_ID" >/dev/null 2>&1 || true

created=0
existing=0

for secret in "${SECRETS[@]}"; do
  if gcloud secrets describe "$secret" --project "$PROJECT_ID" >/dev/null 2>&1; then
    existing=$((existing + 1))
    echo "  [skip]   $secret (already exists)"
  else
    gcloud secrets create "$secret" \
      --project "$PROJECT_ID" \
      --replication-policy="automatic" \
      --labels="env=$ENV_NAME,managed-by=provision-secrets-sh" >/dev/null
    created=$((created + 1))
    echo "  [create] $secret"
  fi

  if [[ -n "$SERVICE_ACCOUNT" ]]; then
    gcloud secrets add-iam-policy-binding "$secret" \
      --project "$PROJECT_ID" \
      --member="serviceAccount:$SERVICE_ACCOUNT" \
      --role="roles/secretmanager.secretAccessor" \
      --condition=None >/dev/null 2>&1 || true
  fi
done

echo ""
echo "Done. created=$created, existing=$existing, total=${#SECRETS[@]}"
echo ""
echo "Next step: rotate + populate versions per docs/ops/secret-rotation-checklist.md"

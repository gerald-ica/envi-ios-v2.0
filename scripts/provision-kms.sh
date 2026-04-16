#!/usr/bin/env bash
# provision-kms.sh
#
# Creates the Cloud KMS key ring + key used to wrap per-connection data
# encryption keys (DEKs) for OAuth token storage. See Phase 06-07 /
# functions/src/lib/kmsEncryption.ts for the envelope encryption flow.
#
# Resulting resources (idempotent):
#   projects/<project>/locations/global/keyRings/envi-oauth-tokens
#   projects/<project>/locations/global/keyRings/envi-oauth-tokens/cryptoKeys/token-kek
#
# Grants `roles/cloudkms.cryptoKeyEncrypterDecrypter` to the Functions
# runtime service account.
#
# Usage:
#   ./scripts/provision-kms.sh \
#       --project envi-by-informal-staging \
#       --service-account <functions-sa-email>

set -euo pipefail

PROJECT_ID=""
SERVICE_ACCOUNT=""
KEY_RING="envi-oauth-tokens"
KEY_NAME="token-kek"
LOCATION="global"

usage() {
  cat <<EOF
Usage: $0 --project <gcp-project-id> [--service-account <sa-email>] [--location global]

Options:
  --project <id>           Required. GCP project id.
  --service-account <sa>   Optional. Functions runtime SA to grant encrypter/
                           decrypter role on the key.
  --location <region>      Optional. Defaults to "global". Keep in sync with
                           functions/src/lib/kmsEncryption.ts.
  -h, --help               Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_ID="$2"; shift 2 ;;
    --service-account) SERVICE_ACCOUNT="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
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

gcloud config set project "$PROJECT_ID" >/dev/null
gcloud services enable cloudkms.googleapis.com --project "$PROJECT_ID" >/dev/null 2>&1 || true

echo "Project:         $PROJECT_ID"
echo "Location:        $LOCATION"
echo "Key ring:        $KEY_RING"
echo "Key:             $KEY_NAME"
echo "Service account: ${SERVICE_ACCOUNT:-(skipped)}"
echo ""

# Key ring
if gcloud kms keyrings describe "$KEY_RING" \
     --location "$LOCATION" --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "  [skip]   keyring $KEY_RING already exists"
else
  gcloud kms keyrings create "$KEY_RING" \
    --location "$LOCATION" \
    --project "$PROJECT_ID"
  echo "  [create] keyring $KEY_RING"
fi

# Key
if gcloud kms keys describe "$KEY_NAME" \
     --keyring "$KEY_RING" --location "$LOCATION" --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "  [skip]   key $KEY_NAME already exists"
else
  gcloud kms keys create "$KEY_NAME" \
    --keyring "$KEY_RING" \
    --location "$LOCATION" \
    --purpose "encryption" \
    --default-algorithm "google-symmetric-encryption" \
    --rotation-period "90d" \
    --next-rotation-time "$(date -u -v+90d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)" \
    --project "$PROJECT_ID"
  echo "  [create] key $KEY_NAME (90-day rotation)"
fi

# IAM binding
if [[ -n "$SERVICE_ACCOUNT" ]]; then
  gcloud kms keys add-iam-policy-binding "$KEY_NAME" \
    --keyring "$KEY_RING" \
    --location "$LOCATION" \
    --project "$PROJECT_ID" \
    --member "serviceAccount:$SERVICE_ACCOUNT" \
    --role "roles/cloudkms.cryptoKeyEncrypterDecrypter" \
    --condition=None >/dev/null 2>&1 || true
  echo "  [bind]   $SERVICE_ACCOUNT -> roles/cloudkms.cryptoKeyEncrypterDecrypter"
fi

echo ""
echo "KMS key resource:"
echo "  projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEY_RING/cryptoKeys/$KEY_NAME"

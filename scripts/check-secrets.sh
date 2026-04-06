#!/bin/bash
# Checks for common secret patterns in staged/tracked files
# Exit 1 if potential secrets found

set -euo pipefail

PATTERNS=(
  'AKIA[0-9A-Z]{16}'                            # AWS access key
  'sk-[a-zA-Z0-9]{20,}'                         # API keys (OpenAI, Stripe, etc.)
  'ghp_[a-zA-Z0-9]{36}'                         # GitHub PAT
  'AIza[0-9A-Za-z_-]{35}'                       # Google API key
  'client_secret.*=.*[a-zA-Z0-9]{20,}'          # Generic client secrets
  'password\s*[:=]\s*["\x27][^"\x27]{8,}'       # Hardcoded passwords
)

FOUND=0
for pattern in "${PATTERNS[@]}"; do
  if git diff --cached --diff-filter=ACMR -U0 | grep -qiE "$pattern"; then
    echo "❌ Potential secret found matching: $pattern"
    FOUND=1
  fi
done

if [[ $FOUND -eq 1 ]]; then
  echo ""
  echo "Secrets detected in staged changes. Remove them before committing."
  echo "Use environment variables or .env files (gitignored) instead."
  exit 1
fi

echo "✅ No secrets detected in staged changes."

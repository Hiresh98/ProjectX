#!/usr/bin/env bash
# Create/update this stack. Safe to re-run (idempotent).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK="$(basename "$DIR")"
cd "$DIR"
echo "=== [$STACK] terraform apply ==="
terraform init -input=false
terraform apply -auto-approve -input=false
echo "[$STACK] UP."

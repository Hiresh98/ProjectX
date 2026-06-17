#!/usr/bin/env bash
# Destroy this stack so it stops incurring cost. Safe to re-run.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK="$(basename "$DIR")"
cd "$DIR"
echo "=== [$STACK] terraform destroy ==="
terraform init -input=false
terraform destroy -auto-approve -input=false
echo "[$STACK] DOWN."

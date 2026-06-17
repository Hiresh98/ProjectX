#!/usr/bin/env bash
# Bring up the whole platform in dependency order. Optional stacks (bastion,
# github-oidc, iam) are not included - run their own up.sh when needed.
set -euo pipefail
STACKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for s in vpc ecr rds-sg rds nat eks irsa addons app; do
  echo ""
  echo "##### STACK: $s #####"
  bash "$STACKS/$s/up.sh"
done
echo ""
echo "All stacks UP."

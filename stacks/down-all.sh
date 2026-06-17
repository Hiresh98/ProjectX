#!/usr/bin/env bash
# Tear down stacks. Default = COST-SAVING (removes billable stacks, keeps free
# layer). Use: ALL=true ./down-all.sh  to destroy everything.
set -uo pipefail
STACKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL="${ALL:-false}"

COSTLY="app addons irsa eks nat bastion"
FREE="rds rds-sg ecr vpc"
if [ "$ALL" = "true" ]; then ORDER="$COSTLY $FREE"; else ORDER="$COSTLY"; fi

for s in $ORDER; do
  if [ -f "$STACKS/$s/down.sh" ]; then
    echo ""
    echo "##### DOWN STACK: $s #####"
    bash "$STACKS/$s/down.sh"
  fi
done

if [ "$ALL" = "true" ]; then
  echo "Everything destroyed (iam + github-oidc, if used, removed separately)."
else
  echo "Costly stacks removed. Free layer (vpc/ecr/rds/iam) still running at ~\$0."
fi

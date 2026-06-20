#!/usr/bin/env bash
# Deploy the edge stack (us-east-1): hosted zone + optional CloudFront custom domain.
#   ./scripts/deploy-edge.sh false   # phase 1: hosted zone only (fast)
#   ./scripts/deploy-edge.sh true    # phase 2: + ACM cert + CloudFront + alias
#                                    #          run AFTER scripts/delegate-ns.sh
#                                    #          (blocks ~5-15 min for cert issuance + CF deploy)
set -euo pipefail
cd "$(dirname "$0")/.."

ENABLE="${1:-false}"
APP_STACK=aisl-click-app
EDGE_STACK=aisl-click-edge

ORIGIN=$(aws cloudformation describe-stacks --stack-name "$APP_STACK" --region eu-west-1 \
  --query "Stacks[0].Outputs[?OutputKey==\`ApiEndpoint\`].OutputValue" --output text)
echo "Origin HTTP API: $ORIGIN"

aws cloudformation deploy \
  --stack-name "$EDGE_STACK" --template-file infra/edge.yaml \
  --no-fail-on-empty-changeset --region us-east-1 \
  --parameter-overrides OriginUrl="$ORIGIN" DomainName=aisl.click EnableCustomDomain="$ENABLE"

aws cloudformation describe-stacks --stack-name "$EDGE_STACK" --region us-east-1 \
  --query "Stacks[0].Outputs" --output table

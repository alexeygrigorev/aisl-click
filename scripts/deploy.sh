#!/usr/bin/env bash
# Deploy the app stack (eu-west-1): build arm64 -> upload to S3 -> cloudformation deploy.
# This is exactly what CI does on push. Reads ARTIFACT_BUCKET from .env (or the env).
set -euo pipefail
cd "$(dirname "$0")/.."

# load local .env if present (gitignored) — defines ARTIFACT_BUCKET etc.
[ -f .env ] && set -a && . ./.env && set +a

: "${ARTIFACT_BUCKET:?set ARTIFACT_BUCKET (see .env.template)}"
REGION=eu-west-1
APP_STACK=aisl-click-app
KEY=redirector/latest.zip

./scripts/build.sh
aws s3 cp dist/bootstrap.zip "s3://${ARTIFACT_BUCKET}/${KEY}"

aws cloudformation deploy \
  --stack-name "$APP_STACK" --template-file infra/app.yaml \
  --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region "$REGION" \
  --parameter-overrides CodeS3Bucket="$ARTIFACT_BUCKET" CodeS3Key="$KEY"

aws cloudformation describe-stacks --stack-name "$APP_STACK" --region "$REGION" \
  --query "Stacks[0].Outputs" --output table

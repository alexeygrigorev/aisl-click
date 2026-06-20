#!/usr/bin/env bash
# Point aisl.click's nameservers at the CloudFormation-managed hosted zone (edge stack).
# Run after `deploy-edge.sh false`. Domain registration is global (us-east-1 endpoint).
set -euo pipefail

ZONE_ID=$(aws cloudformation describe-stacks --stack-name aisl-click-edge --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey==\`HostedZoneId\`].OutputValue" --output text)
echo "Hosted zone: $ZONE_ID"

# Nameservers must be [{Name:...}, ...] (objects, not bare strings).
aws route53 get-hosted-zone --id "$ZONE_ID" --output json \
  | jq '{DomainName:"aisl.click", Nameservers:[.DelegationSet.NameServers[]|{Name:.}]}' > /tmp/ns.json
echo "Payload:"; cat /tmp/ns.json

aws route53domains update-domain-nameservers \
  --region us-east-1 --cli-input-json file:///tmp/ns.json

echo "Updated aisl.click NS:"
aws route53domains get-domain-detail --domain-name aisl.click --region us-east-1 --query "NameServers" --output table

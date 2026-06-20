# aisl.click — short-link redirector

Rust Lambda mapping `aisl.click/<slug>` → a destination URL via an inline
`REDIRECTS` map. 128MB, `provided.al2023`, **arm64** in CI / x86_64 for local
tests. 302 + `cache-control: no-store` so edits are instant.

> This account's SCP blocks **public Lambda Function URLs** (verified:
> `AccessDeniedException` on invoke). So the Lambda is exposed via an **API
> Gateway HTTP API** instead (it invokes Lambda as the `apigateway` service
> principal, which the SCP allows). CloudFront fronts the HTTP API for the
> custom domain.

## Two stacks, two regions

| Stack | Region | Contains | Deploy |
|-------|--------|----------|--------|
| `aisl-click-app` | eu-west-1 | IAM role + arm64 Lambda + HTTP API (public) | **CI on every push** |
| `aisl-click-edge` | us-east-1 | Route 53 hosted zone + ACM cert + CloudFront + alias | one-time manual (2 phases) |

The edge stack is us-east-1 because **CloudFront's ACM cert must live there**.
Domain **registration** isn't a CloudFormation resource — one-time CLI (already
done via `route53domains register-domain`, ~$3/yr, auto-renew).

## Add / change a link

Edit `REDIRECTS` in `redirector/src/main.rs`, run `cargo test` locally (x86_64),
push to `main`. CI rebuilds arm64 and redeploys the app stack.

## One-time setup

```bash
BUCKET=aisl-click-artifacts-<account-id>   # S3 bucket (globally unique) for the lambda zip

# 1. app stack (eu-west-1) — the redirector on a public HTTP API
ARTIFACT_BUCKET=$BUCKET ./scripts/deploy.sh

# 2. edge phase 1 (us-east-1) — hosted zone only
./scripts/deploy-edge.sh false

# 3. delegate aisl.click's NS to the new zone
./scripts/delegate-ns.sh

# 4. edge phase 2 — + ACM cert + CloudFront + alias (blocks ~5-15 min)
./scripts/deploy-edge.sh true
```

After step 4: `https://aisl.click/munich` → 302 → the workshop URL.

## CI/CD (GitHub Actions, OIDC — no static key)

The runner assumes IAM role `aisl-click-deploy` via **GitHub OIDC** — there are no
long-lived AWS credentials and no IAM user. The role's trust policy is pinned to
this repo's `main` branch only, so nothing else can assume it. It can deploy only
`aisl-click-app` (plus the Lambda role's lifecycle, scoped to `aisl-click-redirector`).

```bash
# create the GitHub OIDC provider + the deploy role (assumed by the repo)
aws cloudformation deploy --stack-name aisl-click-deploy \
  --template-file infra/github-deploy.yaml --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides ArtifactBucket=$BUCKET GitHubRepo=alexeygrigorev/aisl-click \
  --region eu-west-1

# role ARN to put in the GitHub variable below
aws cloudformation describe-stacks --stack-name aisl-click-deploy --region eu-west-1 \
  --query "Stacks[0].Outputs[?OutputKey==\`DeployRoleArn\`].OutputValue" --output text
```

In the GitHub repo (Settings → Secrets and variables → Actions → Variables) — **no secrets needed**:
- `AISL_ARTIFACT_BUCKET` = `$BUCKET`
- `AISL_DEPLOY_ROLE_ARN` = the ARN printed above

Push to `main` → build arm64 → upload zip → deploy app stack (as the assumed role).

## Layout

```
redirector/
  src/main.rs             edit REDIRECTS here; unit tests for local `cargo test`
  .cargo/config.toml      arm64 cross-link (rust-lld + self-contained musl, no cross-toolchain)
infra/
  app.yaml                eu-west-1: role + arm64 lambda + HTTP API (public)
  edge.yaml               us-east-1: hosted zone + cert + cloudfront + alias
  github-deploy.yaml      CI deploy role (GitHub OIDC; no static key, no IAM user)
.github/workflows/deploy.yml   build arm64 → s3 → deploy app
scripts/                  build.sh · test.sh · deploy.sh · deploy-edge.sh · delegate-ns.sh
```

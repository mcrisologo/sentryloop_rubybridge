# sentry_github_dispatch

Rails engine: **Sentry issue-alert webhook → authenticated GitHub `repository_dispatch`**.

This repository is **`sentry_loop_bridge`** (standalone). Pair with the separate npm package
[`sentry_loop_orchestrator`](https://github.com/mcrisologo/sentry_loop_orchestrator)
(`@gohub/sentry-loop-orchestrator`) for the Cursor investigate → fix/skeptic → PR loop.

## Install

### Git source (recommended for apps)

```ruby
# Gemfile
gem 'sentry_github_dispatch', git: 'https://github.com/OWNER/sentry_loop_bridge.git'
```

### Local path (sibling checkout)

```text
ror/dasig/
  dasig/                         # Rails app
  sentry_loop/                   # local workspace only (not a git repo)
    sentry_loop_bridge/          # this git repo
    sentry_loop_orchestrator/    # separate git repo
```

```ruby
gem 'sentry_github_dispatch', path: '../sentry_loop/sentry_loop_bridge'
```

```bash
bundle install
```

## Mount

```ruby
mount SentryGithubDispatch::Engine => '/internal/webhooks/sentry'
```

Webhook URL:

```text
https://<host>/internal/webhooks/sentry/<WEBHOOK_TOKEN>/auto_fix
```

## Configure

| Variable | Required | Notes |
|----------|----------|-------|
| `SENTRY_AUTO_FIX_ENABLED` | yes to run | Default **off**. Set `true`/`1`/`on`/`yes` |
| `SENTRY_AUTO_FIX_WEBHOOK_TOKEN` | yes | Path segment |
| `SENTRY_AUTO_FIX_GITHUB_PAT` | yes | Fine-grained: Actions write on one repo |
| `SENTRY_AUTO_FIX_GITHUB_OWNER` | yes | No default |
| `SENTRY_AUTO_FIX_GITHUB_REPO` | yes | No default |
| `SENTRY_AUTO_FIX_HMAC_SECRET` | yes by default | Body-bound HMAC (`Sentry-Hook-Signature`) |
| `SENTRY_AUTO_FIX_REQUIRE_HMAC` | no | Default **true**. Set `false` only for header-only hosts |
| `SENTRY_AUTO_FIX_WEBHOOK_SECRET` | optional | Extra header secret; alone is weaker than HMAC |
| `SENTRY_AUTO_FIX_HMAC_MAX_SKEW_SECONDS` | no | Default `300` — rejects stale `Sentry-Hook-Timestamp` |
| `SENTRY_AUTO_FIX_ALLOWED_ENVIRONMENTS` | no | Default `production` |
| `SENTRY_AUTO_FIX_WEBHOOK_SECRET_HEADER` | no | Default `X-Sentry-Loop-Webhook-Secret` |

```ruby
SentryGithubDispatch.configure do |c|
  c.load_from_env!
end

require 'sentry_github_dispatch/rack_attack'
SentryGithubDispatch::RackAttack.throttle!(limit: 10, period: 60)
```

## Bridge vs other trigger options

The orchestrator README documents **Option A (this gem)**, **Option B (Worker/Zapier)**, and
**Option C (manual `workflow_dispatch`)** with pros/cons:
[`sentry_loop_orchestrator` README — Bridge options](https://github.com/mcrisologo/sentry_loop_orchestrator#bridge-options-sentry--github).

## Security

See [SECURITY.md](./SECURITY.md). Sequence diagram + naming: [ARCHITECTURE.md](./ARCHITECTURE.md).
Wire shape: [CONTRACT.md](./CONTRACT.md).

## Tests

```bash
bundle install
bundle exec rspec
```

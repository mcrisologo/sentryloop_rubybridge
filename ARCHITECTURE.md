# Architecture — sentryloop_rubybridge

**Public names**

| Layer | Name |
|-------|------|
| GitHub repo | `sentryloop_rubybridge` |
| Ruby gem | `sentry_github_dispatch` |
| Env prefix | `SENTRY_AUTO_FIX_*` |

Companion: [`sentryloop_orchestrator`](https://github.com/mcrisologo/sentryloop_orchestrator).

## Runtime sequence

```text
Sentry alert
  → WebhooksController#create
  → Enqueue
       1. VerifyRequest   (path token + HMAC and/or header secret + timestamp skew)
       2. kill switch     (enabled? — auth still ran)
       3. ParsePayload
       4. Allowlist       (environment)
       5. cache claim     (Rails.cache write unless_exist)
       6. DispatchJob.perform_later
  → DispatchJob
       → DispatchGithub   (Faraday → repository_dispatch)
       → classify 4xx (discard) vs 5xx (retry) vs timeout (keep claim)
```

## Security defaults

- Kill switch **off** unless `SENTRY_AUTO_FIX_ENABLED=true|1|on|yes`
- `require_hmac` **true** by default (set `SENTRY_AUTO_FIX_REQUIRE_HMAC=false` for header-only hosts)
- When HMAC is configured, `Sentry-Hook-Timestamp` must be within `hmac_max_skew_seconds` (default 300)

## Docs

- Wire contract: [`CONTRACT.md`](./CONTRACT.md)
- Operator security: [`SECURITY.md`](./SECURITY.md)
- Host product mind maps live in the consuming app (e.g. Dasig `docs/mind_maps/sentry_auto_fix.md`)

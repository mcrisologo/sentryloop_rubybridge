# Security

## Threat model (bridge)

| Surface | Risk | Mitigations |
|---------|------|-------------|
| Sentry webhook forgery | Trigger GitHub dispatch | Path token + **HMAC by default** (`require_hmac=true`) over raw body; optional header secret |
| Stale / clock-skewed deliveries | Accept ancient hooks | Soft freshness check on `Sentry-Hook-Timestamp` (default 300s). **Not** cryptographic replay defense — Sentry’s signature does not bind the timestamp |
| Captured body+signature replay | Re-fire after claim TTL | Atomic cache claim per `issue_id`; keep claim across retryable GitHub failures; short TTL |
| Misconfigured public install | Dispatch to wrong repo | No owner/repo defaults; kill switch default **off**; owner/repo must be GitHub name charset (no `/` or `..`) |
| Secret leakage | PAT in git or logs | Never commit `.env`; store PAT in host secrets only; job logs omit GitHub response bodies |
| Duplicate spend | Concurrent webhooks / retries | Atomic cache claim (`unless_exist`); discard non-retryable 4xx after releasing claim |
| Oversized webhook | Memory / HMAC DoS | Reject bodies over 256 KiB (`413`) before HMAC |
| Issue URL SSRF | Dispatch payload points off Sentry | HTTPS + `/issues/` + allowlisted hosts (`sentry.io` by default) |

## Operator checklist

1. Set `SENTRY_AUTO_FIX_ENABLED=true` only after secrets are ready.
2. Prefer a Sentry Internal Integration so `Sentry-Hook-Signature` (+ timestamp) are present.
3. Header-only hosts must set `SENTRY_AUTO_FIX_REQUIRE_HMAC=false` explicitly (weaker; body not bound).
4. Fine-grained GitHub PAT on **one** repo (`actions: write` for `repository_dispatch`).
5. Use a shared Rails cache store in multi-process Puma (not MemoryStore alone).
6. Enable `SentryGithubDispatch::RackAttack.throttle!` on the host.
7. Create the `sentry-auto-fix-lock` label on the target repo (orchestrator requires it).

## Reporting

Open a private security advisory on this repository.

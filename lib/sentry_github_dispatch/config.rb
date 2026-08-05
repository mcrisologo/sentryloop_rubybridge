# frozen_string_literal: true

module SentryGithubDispatch
  # Convenience accessors used by services (delegates to configuration).
  module Config
    module_function

    def enabled?
      SentryGithubDispatch.configuration.enabled?
    end

    def webhook_token
      SentryGithubDispatch.configuration.webhook_token.to_s
    end

    def webhook_secret
      SentryGithubDispatch.configuration.webhook_secret.to_s
    end

    def hmac_secret
      SentryGithubDispatch.configuration.hmac_secret.to_s
    end

    def github_pat
      SentryGithubDispatch.configuration.github_pat.to_s
    end

    def github_owner
      SentryGithubDispatch.configuration.github_owner
    end

    def github_repo
      SentryGithubDispatch.configuration.github_repo
    end

    def allowed_environments
      SentryGithubDispatch.configuration.allowed_environments
    end

    def idempotency_ttl
      SentryGithubDispatch.configuration.idempotency_ttl
    end

    def webhook_secret_header
      SentryGithubDispatch.configuration.webhook_secret_header
    end

    def event_type
      SentryGithubDispatch.configuration.event_type
    end

    def require_hmac
      SentryGithubDispatch.configuration.require_hmac
    end

    def hmac_max_skew_seconds
      SentryGithubDispatch.configuration.hmac_max_skew_seconds
    end

    def max_stack_chars
      SentryGithubDispatch.configuration.max_stack_chars
    end

    def configured?
      SentryGithubDispatch.configuration.configured?
    end
  end
end

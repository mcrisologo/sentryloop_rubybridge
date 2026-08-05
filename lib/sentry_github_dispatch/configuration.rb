# frozen_string_literal: true

module SentryGithubDispatch
  class Configuration
    attr_accessor :webhook_token,
                  :webhook_secret,
                  :hmac_secret,
                  :github_pat,
                  :github_owner,
                  :github_repo,
                  :allowed_environments,
                  :idempotency_ttl,
                  :webhook_secret_header,
                  :event_type,
                  :enabled,
                  :require_hmac,
                  :hmac_max_skew_seconds,
                  :max_stack_chars

    def initialize
      load_from_env!
    end

    def load_from_env!
      # Safe public default: off until explicitly enabled.
      @enabled = env_flag_enabled?('SENTRY_AUTO_FIX_ENABLED', default: false)
      # Prefer body-bound HMAC in production. Header-only hosts must opt out
      # explicitly with SENTRY_AUTO_FIX_REQUIRE_HMAC=false.
      @require_hmac = env_flag_enabled?('SENTRY_AUTO_FIX_REQUIRE_HMAC', default: true)
      @webhook_token = ENV['SENTRY_AUTO_FIX_WEBHOOK_TOKEN'].to_s
      @webhook_secret = ENV['SENTRY_AUTO_FIX_WEBHOOK_SECRET'].to_s
      @hmac_secret = ENV['SENTRY_AUTO_FIX_HMAC_SECRET'].to_s
      @github_pat = ENV['SENTRY_AUTO_FIX_GITHUB_PAT'].to_s
      @github_owner = ENV['SENTRY_AUTO_FIX_GITHUB_OWNER'].to_s
      @github_repo = ENV['SENTRY_AUTO_FIX_GITHUB_REPO'].to_s
      @allowed_environments = ENV.fetch('SENTRY_AUTO_FIX_ALLOWED_ENVIRONMENTS', 'production')
                                 .split(',')
                                 .map { |e| e.strip.downcase }
                                 .reject(&:blank?)
      @idempotency_ttl = Integer(ENV.fetch('SENTRY_AUTO_FIX_IDEMPOTENCY_TTL_SECONDS', 21_600))
      @hmac_max_skew_seconds = Integer(ENV.fetch('SENTRY_AUTO_FIX_HMAC_MAX_SKEW_SECONDS', 300))
      @max_stack_chars = Integer(ENV.fetch('SENTRY_AUTO_FIX_MAX_STACK_CHARS', 8_000))
      @webhook_secret_header = ENV.fetch(
        'SENTRY_AUTO_FIX_WEBHOOK_SECRET_HEADER',
        'X-Sentry-Loop-Webhook-Secret'
      )
      @event_type = ENV.fetch('SENTRY_AUTO_FIX_EVENT_TYPE', 'sentry_issue')
    end

    def enabled?
      @enabled
    end

    def configured?
      webhook_token.present? &&
        github_pat.present? &&
        github_owner.present? &&
        github_repo.present? &&
        (webhook_secret.present? || hmac_secret.present?) &&
        (!require_hmac || hmac_secret.present?)
    end

    private

    def env_flag_enabled?(name, default:)
      raw = ENV[name].to_s.strip.downcase
      return default if raw.blank?

      %w[1 true on yes].include?(raw)
    end
  end
end

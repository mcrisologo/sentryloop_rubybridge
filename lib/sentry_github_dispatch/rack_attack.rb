# frozen_string_literal: true

module SentryGithubDispatch
  # Optional Rack::Attack registration for host apps that use rack-attack.
  module RackAttack
    module_function

    def throttle!(limit: 10, period: 60)
      return unless defined?(::Rack::Attack)

      ::Rack::Attack.throttle('sentry_github_dispatch/ip', limit: limit, period: period) do |req|
        req.ip if req.post? && req.path.match?(%r{/[^/]+/auto_fix\z})
      end
    end
  end
end

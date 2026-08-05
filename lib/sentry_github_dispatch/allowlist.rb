# frozen_string_literal: true

module SentryGithubDispatch
  class Allowlist
    def self.allowed?(payload)
      new(payload).allowed?
    end

    def initialize(payload)
      @payload = payload.with_indifferent_access
    end

    def allowed?
      env = @payload[:environment].to_s.strip.downcase
      return false if env.blank?

      Config.allowed_environments.include?(env)
    end
  end
end

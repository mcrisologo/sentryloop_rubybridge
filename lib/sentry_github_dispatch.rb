# frozen_string_literal: true

require 'sentry_github_dispatch/version'
require 'sentry_github_dispatch/configuration'
require 'sentry_github_dispatch/config'
require 'sentry_github_dispatch/verify_request'
require 'sentry_github_dispatch/parse_payload'
require 'sentry_github_dispatch/allowlist'
require 'sentry_github_dispatch/dispatch_github'
require 'sentry_github_dispatch/enqueue'

require 'sentry_github_dispatch/engine' if defined?(Rails)

module SentryGithubDispatch
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

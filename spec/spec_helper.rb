# frozen_string_literal: true

require 'active_support/all'
require 'active_job'
require 'faraday'
require 'webmock/rspec'
require 'openssl'

lib = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Load the gem WITHOUT the Rails engine (Rails is not defined yet, so the
# umbrella file skips `require .../engine`). We provide a minimal Rails shim
# afterwards for the runtime-only `Rails.cache` / `Rails.logger` calls.
require 'sentry_github_dispatch'

module Rails
  class << self
    def cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def logger
      @logger ||= ActiveSupport::Logger.new(IO::NULL)
    end
  end
end

require File.expand_path('../app/jobs/sentry_github_dispatch/dispatch_job.rb', __dir__)

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Rails.logger

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random

  config.before do
    ENV.keys.grep(/\ASENTRY_AUTO_FIX_/).each { |k| ENV.delete(k) }
    SentryGithubDispatch.reset_configuration!
    Rails.cache.clear
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end
end

module ConfigHelpers
  def configure_bridge(**opts)
    SentryGithubDispatch.configure do |c|
      c.enabled = opts.fetch(:enabled, true)
      c.webhook_token = opts.fetch(:webhook_token, 'tok')
      c.webhook_secret = opts.fetch(:webhook_secret, '')
      c.hmac_secret = opts.fetch(:hmac_secret, 'hmac-secret')
      c.require_hmac = opts.fetch(:require_hmac, true)
      c.github_pat = opts.fetch(:github_pat, 'pat')
      c.github_owner = opts.fetch(:github_owner, 'owner')
      c.github_repo = opts.fetch(:github_repo, 'repo')
      c.allowed_environments = opts.fetch(:allowed_environments, ['production'])
      c.idempotency_ttl = opts.fetch(:idempotency_ttl, 3600)
      c.hmac_max_skew_seconds = opts.fetch(:hmac_max_skew_seconds, 300)
      c.max_stack_chars = opts.fetch(:max_stack_chars, 8_000)
      c.event_type = opts.fetch(:event_type, 'sentry_issue')
    end
  end

  def hmac_for(body, secret: 'hmac-secret')
    OpenSSL::HMAC.hexdigest('SHA256', secret, body)
  end

  def enqueued_dispatch_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
      job[:job] == SentryGithubDispatch::DispatchJob
    end
  end
end

RSpec.configure { |c| c.include ConfigHelpers }

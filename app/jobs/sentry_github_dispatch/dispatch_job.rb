# frozen_string_literal: true

module SentryGithubDispatch
  class DispatchJob < ActiveJob::Base
    queue_as :default

    def perform(payload)
      payload = payload.with_indifferent_access
      result = DispatchGithub.call(payload: payload)
      return if result.success?

      Rails.logger.error(
        "[sentry_github_dispatch] GitHub dispatch failed issue=#{payload[:issue_id]} " \
        "status=#{result.status} retryable=#{result.retryable?}"
      )

      # The POST may have reached GitHub before the timeout. Keep the claim and
      # stop: retrying would emit a second repository_dispatch.
      return if result.ambiguous?

      if result.retryable?
        # Keep the claim across retries (5xx/429/timeout) so a concurrent webhook
        # cannot enqueue a second repository_dispatch while ActiveJob backs off.
        raise "Sentry GitHub dispatch failed (#{result.status})"
      end

      # Terminal non-retryable failure (auth/config): free the slot for a later webhook.
      Enqueue.release_claim!(payload[:issue_id]) if payload[:issue_id].present?
    end
  end
end

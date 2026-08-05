# frozen_string_literal: true

require 'faraday'

module SentryGithubDispatch
  class DispatchGithub
    # Client/config errors that will never succeed on retry.
    NON_RETRYABLE_STATUSES = [400, 401, 403, 404, 422].freeze

    Result = Data.define(:ok, :status, :error, :retryable) do
      def success?
        ok
      end

      def retryable?
        retryable
      end

      def ambiguous?
        status == 504
      end
    end

    ENDPOINT = 'https://api.github.com/repos/%<owner>s/%<repo>s/dispatches'
    OPEN_TIMEOUT = 5
    TIMEOUT = 15

    def self.call(payload:)
      new(payload: payload).call
    end

    def initialize(payload:)
      @payload = payload.with_indifferent_access
    end

    def call
      return Result.new(ok: false, status: 503, error: 'not configured', retryable: false) unless Config.configured?
      return Result.new(ok: false, status: 503, error: 'disabled', retryable: false) unless Config.enabled?

      response = connection.post(url) do |req|
        req.headers['Authorization'] = "Bearer #{Config.github_pat}"
        req.headers['Accept'] = 'application/vnd.github+json'
        req.headers['X-GitHub-Api-Version'] = '2022-11-28'
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json
      end

      if response.status == 204 || response.success?
        Result.new(ok: true, status: response.status, error: nil, retryable: false)
      else
        Result.new(
          ok: false,
          status: response.status,
          error: response.body.to_s.truncate(500),
          retryable: retryable_status?(response.status)
        )
      end
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      # GitHub may already have accepted the POST. This is terminal-but-ambiguous:
      # keep the claim and never re-POST repository_dispatch.
      Result.new(ok: false, status: 504, error: e.message, retryable: false)
    rescue Faraday::Error => e
      Result.new(ok: false, status: 502, error: e.message, retryable: true)
    end

    private

    def retryable_status?(status)
      code = status.to_i
      return false if NON_RETRYABLE_STATUSES.include?(code)

      code >= 500 || code == 429
    end

    def connection
      Faraday.new do |f|
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = TIMEOUT
      end
    end

    def url
      format(ENDPOINT, owner: Config.github_owner, repo: Config.github_repo)
    end

    def body
      {
        event_type: Config.event_type,
        client_payload: {
          issue_id: @payload[:issue_id],
          issue_url: @payload[:issue_url],
          title: @payload[:title],
          culprit: @payload[:culprit],
          environment: @payload[:environment],
          count: @payload[:count],
          level: @payload[:level],
          stacktrace: truncate_stack(@payload[:stacktrace])
        }.compact
      }
    end

    def truncate_stack(stack)
      return if stack.blank?

      max = Config.max_stack_chars
      return stack if stack.length <= max

      "#{stack[0, max]}\n…[truncated #{stack.length - max} chars]"
    end
  end
end

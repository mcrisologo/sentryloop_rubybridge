# frozen_string_literal: true

module SentryGithubDispatch
  class Enqueue
    Result = Data.define(:ok, :status, :reason) do
      def success?
        ok
      end
    end

    MAX_RAW_BODY = 262_144 # 256 KiB

    def self.call(token:, header_secret:, signature:, raw_body:, params:, hook_timestamp: nil)
      new(
        token: token,
        header_secret: header_secret,
        signature: signature,
        raw_body: raw_body,
        params: params,
        hook_timestamp: hook_timestamp
      ).call
    end

    def initialize(token:, header_secret:, signature:, raw_body:, params:, hook_timestamp: nil)
      @token = token
      @header_secret = header_secret
      @signature = signature
      @raw_body = raw_body
      @params = params
      @hook_timestamp = hook_timestamp
    end

    def call
      if @raw_body.to_s.bytesize > MAX_RAW_BODY
        return Result.new(ok: false, status: :payload_too_large, reason: 'too_large')
      end

      # Always authenticate first (even when disabled) to avoid endpoint fingerprinting.
      verify = VerifyRequest.call(
        token: @token,
        header_secret: @header_secret,
        signature: @signature,
        raw_body: @raw_body,
        hook_timestamp: @hook_timestamp
      )
      return Result.new(ok: false, status: verify.status, reason: 'unauthorized') unless verify.success?

      return Result.new(ok: true, status: :ok, reason: 'disabled') unless Config.enabled?

      parsed = ParsePayload.call(@params)
      return Result.new(ok: true, status: :ok, reason: 'unparseable') unless parsed.success?

      return Result.new(ok: true, status: :ok, reason: 'allowlist') unless Allowlist.allowed?(parsed.payload)

      unless claim_dispatch!(parsed.payload[:issue_id])
        return Result.new(ok: true, status: :accepted, reason: 'idempotent')
      end

      SentryGithubDispatch::DispatchJob.perform_later(parsed.payload.stringify_keys)
      Result.new(ok: true, status: :accepted, reason: 'enqueued')
    end

    def self.cache_key(issue_id)
      "sentry_github_dispatch:dispatched:#{issue_id}"
    end

    def self.release_claim!(issue_id)
      Rails.cache.delete(cache_key(issue_id))
    end

    private

    def claim_dispatch!(issue_id)
      Rails.cache.write(
        self.class.cache_key(issue_id),
        'pending',
        expires_in: Config.idempotency_ttl,
        unless_exist: true
      )
    end
  end
end

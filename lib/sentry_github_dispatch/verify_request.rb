# frozen_string_literal: true

require 'openssl'
require 'active_support/security_utils'

module SentryGithubDispatch
  class VerifyRequest
    Result = Data.define(:ok, :status) do
      def success?
        ok
      end
    end

    def self.call(token:, header_secret:, signature:, raw_body:, hook_timestamp: nil)
      new(
        token: token,
        header_secret: header_secret,
        signature: signature,
        raw_body: raw_body,
        hook_timestamp: hook_timestamp
      ).call
    end

    def initialize(token:, header_secret:, signature:, raw_body:, hook_timestamp: nil)
      @token = token.to_s
      @header_secret = header_secret.to_s
      @signature = signature.to_s
      @raw_body = raw_body.to_s
      @hook_timestamp = hook_timestamp.to_s
    end

    def call
      return Result.new(ok: false, status: :service_unavailable) unless Config.configured?
      return Result.new(ok: false, status: :not_found) unless path_token_valid?
      return Result.new(ok: false, status: :not_found) unless secrets_valid?
      return Result.new(ok: false, status: :not_found) unless timestamp_fresh?

      Result.new(ok: true, status: :ok)
    end

    private

    def path_token_valid?
      secure_compare(@token, Config.webhook_token)
    end

    def secrets_valid?
      if Config.require_hmac
        return false if Config.hmac_secret.blank?

        return hmac_valid? && (Config.webhook_secret.blank? || header_secret_valid?)
      end

      header_ok = Config.webhook_secret.blank? || header_secret_valid?
      hmac_ok = Config.hmac_secret.blank? || hmac_valid?
      header_ok && hmac_ok
    end

    # Soft freshness: when HMAC is in use, require a recent Sentry-Hook-Timestamp.
    # The timestamp is not covered by the HMAC, so this is not cryptographic replay defense.
    def timestamp_fresh?
      return true if Config.hmac_secret.blank?

      ts = Integer(@hook_timestamp, exception: false)
      return false if ts.nil?

      (Time.now.to_i - ts).abs <= Config.hmac_max_skew_seconds
    end

    def header_secret_valid?
      secure_compare(@header_secret, Config.webhook_secret)
    end

    def hmac_valid?
      return false if @signature.blank? || @raw_body.blank?

      digest = OpenSSL::HMAC.hexdigest('SHA256', Config.hmac_secret, @raw_body)
      secure_compare(@signature, digest)
    end

    def secure_compare(left, right)
      return false if left.blank? || right.blank?
      return false unless left.bytesize == right.bytesize

      ActiveSupport::SecurityUtils.secure_compare(left, right)
    end
  end
end

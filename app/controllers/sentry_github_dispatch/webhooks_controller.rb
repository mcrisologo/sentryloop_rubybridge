# frozen_string_literal: true

module SentryGithubDispatch
  class WebhooksController < ActionController::API
    def create
      result = Enqueue.call(
        token: params[:token],
        header_secret: request.headers[Config.webhook_secret_header].to_s,
        signature: request.headers['Sentry-Hook-Signature'].to_s,
        hook_timestamp: request.headers['Sentry-Hook-Timestamp'].to_s,
        raw_body: request.raw_post,
        params: request.request_parameters
      )

      head result.status
    end
  end
end

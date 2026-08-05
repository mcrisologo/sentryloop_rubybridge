# frozen_string_literal: true

require 'uri'

module SentryGithubDispatch
  class ParsePayload
    Result = Data.define(:ok, :payload, :error) do
      def success?
        ok
      end
    end

    def self.call(raw)
      new(raw).call
    end

    def initialize(raw)
      @raw = raw.is_a?(Hash) ? raw.with_indifferent_access : {}
    end

    def call
      issue = nested_issue
      event = nested_event
      identity = extract_identity(issue, event)
      return failure(identity[:error]) if identity[:error]

      Result.new(ok: true, payload: build_payload(identity, issue, event), error: nil)
    end

    private

    def extract_identity(issue, event)
      issue_id = pick_string(
        @raw[:issue_id], @raw[:issueId], @raw[:id],
        issue[:id], issue[:shortId]
      )
      issue_url = pick_string(
        @raw[:issue_url], @raw[:issueUrl], @raw[:permalink], @raw[:url], @raw[:web_url],
        issue[:permalink], issue[:url], issue[:web_url],
        issue_id && "https://sentry.io/issues/#{issue_id}/"
      )
      title = pick_string(
        @raw[:title], issue[:title],
        issue.dig(:metadata, :title),
        event[:title], event[:message], @raw[:message]
      )

      return { error: 'missing issue id' } if issue_id.blank?
      return { error: 'missing issue url' } if issue_url.blank?
      return { error: 'missing title' } if title.blank?
      return { error: 'invalid issue url' } unless sentry_issue_url?(issue_url)

      { issue_id: issue_id.to_s, issue_url: issue_url, title: title, error: nil }
    end

    def sentry_issue_url?(url)
      uri = URI.parse(url.to_s)
      host = uri.host.to_s.downcase
      allowed = ENV.fetch('SENTRY_ALLOWED_HOSTS', 'sentry.io')
                   .split(',')
                   .map { |h| h.strip.downcase }
                   .reject(&:blank?)
      allowed = ['sentry.io'] if allowed.empty?

      uri.is_a?(URI::HTTPS) &&
        uri.path.to_s.include?('/issues/') &&
        allowed.any? { |allowed_host| host == allowed_host || host.end_with?(".#{allowed_host}") }
    rescue URI::InvalidURIError
      false
    end

    def build_payload(identity, issue, event)
      identity.slice(:issue_id, :issue_url, :title).merge(
        culprit: pick_string(@raw[:culprit], issue[:culprit]),
        environment: pick_string(@raw[:environment], event[:environment]),
        count: pick_string(@raw[:count], issue[:count]),
        level: pick_string(@raw[:level], issue[:level]),
        stacktrace: pick_string(@raw[:stacktrace], @raw[:stack_trace], stacktrace_from_event(event))
      )
    end

    def nested_issue
      (
        @raw[:issue] ||
        @raw.dig(:data, :issue) ||
        @raw.dig(:client_payload, :issue) ||
        {}
      ).with_indifferent_access
    end

    def nested_event
      (
        @raw[:event] ||
        @raw.dig(:data, :event) ||
        @raw.dig(:client_payload, :event) ||
        {}
      ).with_indifferent_access
    end

    def stacktrace_from_event(event)
      return event[:stacktrace].to_s if event[:stacktrace].present?

      exception = event.dig(:exception, :values, 0) || {}
      frames = exception.dig(:stacktrace, :frames) || []
      return format_exception(exception, frames) if frames.present?

      entry = Array(event[:entries]).find { |e| e[:type].to_s == 'exception' }
      value = entry&.dig(:data, :values, 0) || {}
      entry_frames = value.dig(:stacktrace, :frames) || []
      return format_exception(value, entry_frames) if entry_frames.present?

      pick_string(event[:message], event[:title])
    end

    def format_exception(exception, frames)
      header = [exception[:type], exception[:value]].compact.join(': ')
      lines = frames.filter_map do |frame|
        file = frame[:filename] || frame[:abs_path] || frame[:absPath]
        next if file.blank?

        line = frame[:lineno] || frame[:lineNo]
        fn = frame[:function]
        loc = line.present? ? "#{file}:#{line}" : file
        fn.present? ? "  #{loc} in `#{fn}`" : "  #{loc}"
      end
      [header, *lines].reject(&:blank?).join("\n")
    end

    def pick_string(*values)
      values.each do |value|
        next if value.nil?

        text = value.to_s.strip
        return text if text.present?
      end
      nil
    end

    def failure(message)
      Result.new(ok: false, payload: nil, error: message)
    end
  end
end

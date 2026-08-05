# frozen_string_literal: true

require 'spec_helper'
require 'openssl'

RSpec.describe SentryGithubDispatch::Enqueue do
  let(:body) do
    {
      issue_id: '7',
      issue_url: 'https://sentry.io/issues/7/',
      title: 'Boom',
      environment: 'production'
    }.to_json
  end
  let(:params) { JSON.parse(body) }
  let(:now) { Time.now.to_i }

  def call(**opts)
    described_class.call(
      token: opts.fetch(:token, 'tok'),
      header_secret: opts.fetch(:header_secret, ''),
      signature: opts.fetch(:signature, hmac_for(body)),
      raw_body: opts.fetch(:raw_body, body),
      params: opts.fetch(:params, params),
      hook_timestamp: opts.fetch(:hook_timestamp, now.to_s)
    )
  end

  before { configure_bridge }

  it 'returns not_found when HMAC is wrong (no status oracle)' do
    result = call(signature: '0' * 64)
    expect(result).not_to be_success
    expect(result.status).to eq(:not_found)
  end

  it 'authenticates then no-ops when disabled' do
    configure_bridge(enabled: false)
    result = call
    expect(result).to be_success
    expect(result.reason).to eq('disabled')
    expect(enqueued_dispatch_jobs).to be_empty
  end

  it 'silently accepts unparseable payloads' do
    result = call(params: { title: 'only' }, raw_body: '{"title":"only"}',
                  signature: hmac_for('{"title":"only"}'))
    expect(result).to be_success
    expect(result.reason).to eq('unparseable')
  end

  it 'silently skips non-allowlisted environments' do
    bad = JSON.parse(body).merge('environment' => 'development')
    raw = bad.to_json
    result = call(params: bad, raw_body: raw, signature: hmac_for(raw))
    expect(result).to be_success
    expect(result.reason).to eq('allowlist')
  end

  it 'claims and enqueues on first delivery' do
    result = call
    expect(result).to be_success
    expect(result.reason).to eq('enqueued')
    expect(enqueued_dispatch_jobs.size).to eq(1)
  end

  it 'is idempotent on a second delivery for the same issue_id' do
    expect(call.reason).to eq('enqueued')
    second = call
    expect(second.reason).to eq('idempotent')
    expect(enqueued_dispatch_jobs.size).to eq(1)
  end
end

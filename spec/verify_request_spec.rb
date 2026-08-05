# frozen_string_literal: true

require 'spec_helper'
require 'openssl'

RSpec.describe SentryGithubDispatch::VerifyRequest do
  let(:body) { '{"issue_id":"1"}' }
  let(:now) { Time.now.to_i }

  def call(**opts)
    described_class.call(
      token: opts.fetch(:token, 'tok'),
      header_secret: opts.fetch(:header_secret, ''),
      signature: opts.fetch(:signature, hmac_for(body)),
      raw_body: opts.fetch(:raw_body, body),
      hook_timestamp: opts.fetch(:hook_timestamp, now.to_s)
    )
  end

  it 'returns 503 when not configured' do
    expect(call.status).to eq(:service_unavailable)
  end

  context 'when configured with HMAC' do
    before { configure_bridge }

    it 'accepts a valid token + HMAC + fresh timestamp' do
      result = call
      expect(result).to be_success
      expect(result.status).to eq(:ok)
    end

    it 'rejects a bad path token with 404' do
      expect(call(token: 'wrong').status).to eq(:not_found)
    end

    it 'rejects a forged HMAC with 404 (no status oracle)' do
      expect(call(signature: '0' * 64).status).to eq(:not_found)
    end

    it 'rejects a stale timestamp with 404' do
      stale = (now - 10_000).to_s
      expect(call(hook_timestamp: stale).status).to eq(:not_found)
    end

    it 'rejects a missing timestamp with 404' do
      expect(call(hook_timestamp: '').status).to eq(:not_found)
    end

    it 'rejects when require_hmac and hmac secret blank' do
      configure_bridge(hmac_secret: '', require_hmac: true, webhook_secret: 'hdr')
      expect(call.status).to eq(:service_unavailable)
    end
  end

  context 'when header-only (require_hmac=false)' do
    before do
      configure_bridge(
        require_hmac: false,
        hmac_secret: '',
        webhook_secret: 'hdr-secret'
      )
    end

    it 'accepts a matching header secret without HMAC or timestamp' do
      result = call(header_secret: 'hdr-secret', signature: '', hook_timestamp: '')
      expect(result).to be_success
    end

    it 'rejects a mismatched header secret with 404' do
      expect(call(header_secret: 'nope', signature: '', hook_timestamp: '').status)
        .to eq(:not_found)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SentryGithubDispatch::DispatchJob do
  let(:payload) do
    {
      'issue_id' => '9',
      'issue_url' => 'https://sentry.io/issues/9/',
      'title' => 'Boom'
    }
  end

  before do
    configure_bridge
    Rails.cache.write(SentryGithubDispatch::Enqueue.cache_key('9'), 'pending')
  end

  def claim_present?
    Rails.cache.exist?(SentryGithubDispatch::Enqueue.cache_key('9'))
  end

  it 'keeps the claim on success' do
    allow(SentryGithubDispatch::DispatchGithub).to receive(:call)
      .and_return(
        SentryGithubDispatch::DispatchGithub::Result.new(
          ok: true, status: 204, error: nil, retryable: false
        )
      )

    described_class.perform_now(payload)
    expect(claim_present?).to be(true)
  end

  it 'releases the claim and does not raise on non-retryable 401' do
    allow(SentryGithubDispatch::DispatchGithub).to receive(:call)
      .and_return(
        SentryGithubDispatch::DispatchGithub::Result.new(
          ok: false, status: 401, error: 'bad', retryable: false
        )
      )

    expect { described_class.perform_now(payload) }.not_to raise_error
    expect(claim_present?).to be(false)
  end

  it 'keeps the claim and raises on retryable 500' do
    allow(SentryGithubDispatch::DispatchGithub).to receive(:call)
      .and_return(
        SentryGithubDispatch::DispatchGithub::Result.new(
          ok: false, status: 500, error: 'boom', retryable: true
        )
      )

    expect { described_class.perform_now(payload) }.to raise_error(/dispatch failed/)
    expect(claim_present?).to be(true)
  end

  it 'keeps the claim and does not raise/re-POST on ambiguous 504 timeout' do
    allow(SentryGithubDispatch::DispatchGithub).to receive(:call)
      .and_return(
        SentryGithubDispatch::DispatchGithub::Result.new(
          ok: false, status: 504, error: 'timeout', retryable: false
        )
      )

    expect { described_class.perform_now(payload) }.not_to raise_error
    expect(claim_present?).to be(true)
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SentryGithubDispatch::DispatchGithub do
  let(:payload) do
    {
      issue_id: '1',
      issue_url: 'https://sentry.io/issues/1/',
      title: 'Boom',
      environment: 'production',
      stacktrace: 'x' * 50
    }
  end

  before { configure_bridge }

  it 'returns success on GitHub 204' do
    stub_request(:post, 'https://api.github.com/repos/owner/repo/dispatches')
      .to_return(status: 204)

    result = described_class.call(payload: payload)
    expect(result).to be_success
    expect(result.retryable?).to be(false)
  end

  it 'marks 401 as non-retryable' do
    stub_request(:post, 'https://api.github.com/repos/owner/repo/dispatches')
      .to_return(status: 401, body: 'bad credentials')

    result = described_class.call(payload: payload)
    expect(result).not_to be_success
    expect(result.status).to eq(401)
    expect(result.retryable?).to be(false)
  end

  it 'marks 500 as retryable' do
    stub_request(:post, 'https://api.github.com/repos/owner/repo/dispatches')
      .to_return(status: 500, body: 'boom')

    result = described_class.call(payload: payload)
    expect(result.retryable?).to be(true)
  end

  it 'marks Faraday timeouts as ambiguous 504 (non-retryable, no re-POST)' do
    stub_request(:post, 'https://api.github.com/repos/owner/repo/dispatches')
      .to_timeout

    result = described_class.call(payload: payload)
    expect(result.status).to eq(504)
    expect(result.retryable?).to be(false)
    expect(result.ambiguous?).to be(true)
  end

  it 'truncates long stacktraces via Config.max_stack_chars' do
    configure_bridge(max_stack_chars: 20)
    stub = stub_request(:post, 'https://api.github.com/repos/owner/repo/dispatches')
           .with { |req|
             stack = JSON.parse(req.body).dig('client_payload', 'stacktrace')
             stack.start_with?('x' * 20) && stack.include?('truncated')
           }
           .to_return(status: 204)

    described_class.call(payload: payload.merge(stacktrace: 'x' * 100))
    expect(stub).to have_been_requested
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SentryGithubDispatch::ParsePayload do
  it 'parses a flat client_payload shape' do
    result = described_class.call(
      issue_id: '42',
      issue_url: 'https://sentry.io/issues/42/',
      title: 'Boom',
      environment: 'production',
      stacktrace: 'app/foo.rb:1'
    )
    expect(result).to be_success
    expect(result.payload[:issue_id]).to eq('42')
    expect(result.payload[:title]).to eq('Boom')
    expect(result.payload[:environment]).to eq('production')
  end

  it 'parses a nested Sentry issue alert shape' do
    result = described_class.call(
      data: {
        issue: {
          id: '99',
          permalink: 'https://sentry.io/issues/99/',
          title: 'Nested boom',
          culprit: 'app/x.rb in call'
        },
        event: {
          environment: 'production',
          exception: {
            values: [
              {
                type: 'NoMethodError',
                value: "undefined method `foo'",
                stacktrace: {
                  frames: [
                    { filename: 'app/x.rb', lineno: 10, function: 'call' }
                  ]
                }
              }
            ]
          }
        }
      }
    )
    expect(result).to be_success
    expect(result.payload[:issue_id]).to eq('99')
    expect(result.payload[:stacktrace]).to include('app/x.rb:10')
  end

  it 'fails when issue id is missing' do
    result = described_class.call(title: 'x', issue_url: 'https://sentry.io/issues/1/')
    expect(result).not_to be_success
    expect(result.error).to eq('missing issue id')
  end

  it 'fails when title is missing' do
    result = described_class.call(issue_id: '1', issue_url: 'https://sentry.io/issues/1/')
    expect(result).not_to be_success
    expect(result.error).to eq('missing title')
  end

  it 'rejects non-Sentry issue URLs' do
    result = described_class.call(
      issue_id: '1',
      issue_url: 'https://evil.example/phishing',
      title: 'Boom'
    )
    expect(result).not_to be_success
    expect(result.error).to eq('invalid issue url')
  end

  it 'rejects issue ids that cannot be a safe cache key' do
    result = described_class.call(
      issue_id: '../1',
      issue_url: 'https://sentry.io/issues/1/',
      title: 'Boom'
    )
    expect(result).not_to be_success
    expect(result.error).to eq('invalid issue id')
  end

  it 'accepts a self-hosted Sentry host from configuration' do
    configure_bridge
    SentryGithubDispatch.configuration.allowed_hosts = ['sentry.example.com']
    result = described_class.call(
      issue_id: '1',
      issue_url: 'https://sentry.example.com/issues/1/',
      title: 'Boom'
    )
    expect(result).to be_success
  end
end


# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SentryGithubDispatch::Configuration do
  def configured_with(**opts)
    configure_bridge(**opts)
    SentryGithubDispatch.configuration
  end

  it 'is configured with a valid GitHub owner/repo and event_type' do
    expect(configured_with).to be_configured
  end

  it 'rejects an owner that can change the GitHub API path' do
    expect(configured_with(github_owner: 'owner/../../etc')).not_to be_configured
  end

  it 'rejects a repo with path separators or parent segments' do
    expect(configured_with(github_repo: 'repo/../other')).not_to be_configured
    expect(configured_with(github_repo: 'repo/dispatches')).not_to be_configured
    expect(configured_with(github_repo: '..')).not_to be_configured
  end

  it 'rejects an event_type GitHub would not accept' do
    expect(configured_with(event_type: 'sentry issue')).not_to be_configured
    expect(configured_with(event_type: 'x' * 101)).not_to be_configured
  end

  it 'loads allowed hosts from SENTRY_AUTO_FIX_ALLOWED_HOSTS' do
    ENV['SENTRY_AUTO_FIX_ALLOWED_HOSTS'] = 'sentry.example.com, sentry.io'
    SentryGithubDispatch.reset_configuration!
    expect(SentryGithubDispatch.configuration.allowed_hosts)
      .to eq(%w[sentry.example.com sentry.io])
  end

  it 'falls back to SENTRY_ALLOWED_HOSTS and drops invalid hostnames' do
    ENV['SENTRY_ALLOWED_HOSTS'] = 'ok.sentry.io, https://evil.example, ..'
    SentryGithubDispatch.reset_configuration!
    expect(SentryGithubDispatch.configuration.allowed_hosts).to eq(%w[ok.sentry.io])
  end
end

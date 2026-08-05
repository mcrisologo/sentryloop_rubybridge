# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SentryGithubDispatch::Allowlist do
  before { configure_bridge(allowed_environments: %w[production staging]) }

  it 'allows a matching environment' do
    expect(described_class.allowed?(environment: 'production')).to be(true)
  end

  it 'rejects a blank environment' do
    expect(described_class.allowed?(environment: '')).to be(false)
  end

  it 'rejects a non-allowlisted environment' do
    expect(described_class.allowed?(environment: 'development')).to be(false)
  end
end

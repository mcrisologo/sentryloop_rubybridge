# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe 'client_payload contract' do
  let(:root) { File.expand_path('..', __dir__) }
  let(:schema) { JSON.parse(File.read(File.join(root, 'schemas/client_payload.schema.json'))) }
  let(:golden) { JSON.parse(File.read(File.join(root, 'fixtures/client_payload.golden.json'))) }

  it 'golden fixture satisfies required schema keys' do
    schema.fetch('required').each do |key|
      expect(golden[key]).not_to be_nil
      expect(golden[key].to_s).not_to be_empty
    end
  end

  it 'ParsePayload accepts the golden fixture' do
    result = SentryGithubDispatch::ParsePayload.call(golden)
    expect(result).to be_success
    expect(result.payload[:issue_id]).to eq(golden['issue_id'].to_s)
  end
end

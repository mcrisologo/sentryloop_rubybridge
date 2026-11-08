# frozen_string_literal: true

require_relative 'lib/sentry_github_dispatch/version'

Gem::Specification.new do |spec|
  spec.name = 'sentry_github_dispatch'
  spec.version = SentryGithubDispatch::VERSION
  spec.authors = ['sentry_loop_bridge maintainers']
  spec.email = ['noreply@users.noreply.github.com']

  spec.summary = 'Secure Sentry webhook bridge that triggers GitHub repository_dispatch'
  spec.description = <<~DESC
    Rails engine that receives authenticated Sentry issue-alert webhooks and enqueues
    a GitHub repository_dispatch (e.g. for Cursor-based auto-fix workflows).
  DESC
  spec.homepage = 'https://github.com/mcrisologo/sentryloop_rubybridge'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.files = Dir.chdir(__dir__) do
    Dir['{app,config,lib}/**/*', 'LICENSE', 'README.md', 'SECURITY.md', 'ARCHITECTURE.md', 'CONTRACT.md'].select { |f| File.file?(f) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday', '>= 2.15'
  spec.add_dependency 'rails', '>= 7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'
end

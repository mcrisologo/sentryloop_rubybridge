# frozen_string_literal: true

module SentryGithubDispatch
  class Engine < ::Rails::Engine
    isolate_namespace SentryGithubDispatch

    config.generators.api_only = true

    initializer 'sentry_github_dispatch.autoload', before: :set_autoload_paths do |app|
      # lib is required via Bundler; app/ is on the engine load paths by default.
    end
  end
end

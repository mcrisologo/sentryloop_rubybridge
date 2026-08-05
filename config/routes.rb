# frozen_string_literal: true

SentryGithubDispatch::Engine.routes.draw do
  post '/:token/auto_fix', to: 'webhooks#create', as: :auto_fix
end

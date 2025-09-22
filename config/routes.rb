Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      get 'auth/me', to: 'auth#me'
      
      # Resources
      resources :projects do
        resources :epics
        resources :tasks
        resources :prds
        resources :roadmaps
      end
      
      resources :tasks
      resources :agents do
        post 'execute', on: :collection
      end
      
      # Integrations
      post 'integrations/slack', to: 'integrations#slack'
      post 'integrations/github', to: 'integrations#github'
      post 'integrations/gmail', to: 'integrations#gmail'
      post 'integrations/webhook', to: 'integrations#webhook'
      
      # Slack Webhooks
      post 'slack/events', to: 'slack_webhook#events'
      post 'slack/interactive', to: 'slack_webhook#interactive'
    end
  end

  # Defines the root path route ("/")
  root "rails/health#show"
end

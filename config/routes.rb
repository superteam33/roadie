Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/signup', to: 'auth#signup'
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      
      # Resources
      resources :projects do
        resources :epics
        resources :tasks
        resources :prds
        resources :roadmaps
        
        # Kanban board endpoint
        get 'kanban', to: 'tasks#kanban'
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
      
      # GitHub Integration
      get 'github/connect', to: 'github#connect'
      get 'github/callback', to: 'github#callback'
      delete 'github/disconnect', to: 'github#disconnect'
      get 'github/status', to: 'github#status'
      
      # GitHub Projects
      get 'github/projects', to: 'github#list_projects'
      post 'github/projects/link', to: 'github#link_project'
      delete 'github/projects/unlink/:project_id', to: 'github#unlink_project'
      post 'github/projects/:project_id/sync', to: 'github#sync_project'
      
      # GitHub Tasks
      post 'github/tasks/create', to: 'github#create_task'
      patch 'github/tasks/:task_id/sync', to: 'github#sync_task'
      get 'github/tasks/:task_id/pull', to: 'github#pull_task'
      
      # GitHub Repositories
      get 'github/repositories', to: 'github#list_repositories'
      
      # GitHub Webhooks
      post 'github/webhook', to: 'github#webhook'
      
      # Email processing (for testing only)
      post 'email/test', to: 'email#test_email_parsing'
    end
  end

  # Defines the root path route ("/")
  root "rails/health#show"
end

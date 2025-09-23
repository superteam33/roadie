class IntegrationWebhookJob < ApplicationJob
  sidekiq_options queue: :default, retry: 2
  
  def perform(integration_type, command, context, user_id)
    user = User.find(user_id)
    IntegrationService.new(integration_type, user).process_command(command, context)
  end
end

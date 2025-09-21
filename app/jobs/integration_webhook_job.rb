class IntegrationWebhookJob < ApplicationJob
  queue_as :default
  
  def perform(integration_type, command, context, user_id)
    user = User.find(user_id)
    IntegrationService.new(integration_type, user).process_command(command, context)
  end
end

class AiAgentJob < ApplicationJob
  queue_as :default
  
  def perform(agent_type, input_data, user_id)
    AiAgentService.new(agent_type).execute(input_data, user_id)
  end
end

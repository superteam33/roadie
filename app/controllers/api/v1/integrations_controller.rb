class Api::V1::IntegrationsController < Api::V1::ApplicationController
  def slack
    command = params[:text] || ''
    context = {
      channel: params[:channel_id],
      user: params[:user_id],
      team: params[:team_id]
    }
    
    begin
      result = IntegrationService.new('slack', current_user).process_command(command, context)
      render json: { 
        response_type: 'in_channel',
        text: "🤖 @roadie processed your request:",
        attachments: [{
          color: 'good',
          text: result.to_s
        }]
      }
    rescue => e
      render json: { 
        response_type: 'ephemeral',
        text: "❌ Error processing request: #{e.message}"
      }
    end
  end
  
  def github
    event_type = request.headers['X-GitHub-Event']
    payload = JSON.parse(request.body.read)
    
    begin
      result = IntegrationService.new('github', current_user).process_command('', {
        event_type: event_type,
        payload: payload
      })
      render json: { message: 'GitHub webhook processed', result: result }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  def gmail
    email_content = params[:email_content] || ''
    context = {
      from: params[:from],
      subject: params[:subject],
      received_at: params[:received_at]
    }
    
    begin
      result = IntegrationService.new('gmail', current_user).process_command(email_content, context)
      render json: { message: 'Email processed', result: result }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  def webhook
    # Generic webhook handler for other integrations
    integration_type = params[:integration_type]
    payload = params[:payload] || {}
    
    begin
      result = IntegrationService.new(integration_type, current_user).process_command('', payload)
      render json: { message: 'Webhook processed', result: result }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end

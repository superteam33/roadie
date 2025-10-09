class Api::V1::GithubController < Api::V1::ApplicationController
  skip_before_action :authenticate_user!, only: [:webhook, :callback]
  skip_before_action :decode_uuid_params, only: [:link_project]
  skip_after_action :encode_response_ids, only: [:link_project]
  
  # OAuth Flow
  def connect
    state = SecureRandom.hex(16)
    
    # Store state in user's record temporarily (we'll clean it up after callback)
    current_user.update!(github_oauth_state: state)
    
    authorization_url = GithubService.authorization_url(state)
    
    render json: { 
      authorization_url: authorization_url,
      message: 'Please authorize the app by visiting the URL'
    }
  end
  
  def callback
    # Find user by state parameter
    user = User.find_by(github_oauth_state: params[:state])
    unless user
      return render json: { error: 'Invalid state parameter' }, status: :forbidden
    end
    
    # Exchange code for access token
    access_token = GithubService.exchange_code_for_token(params[:code])
    
    # Get GitHub user info
    github_service = GithubService.new(OpenStruct.new(github_access_token: access_token))
    github_user = github_service.get_user_info
    
    # Save token and username to user, clear OAuth state
    user.update!(
      github_access_token: access_token,
      github_username: github_user.login,
      github_oauth_state: nil
    )
    
    render json: {
      message: 'GitHub connected successfully',
      github_username: github_user.login
    }
  rescue => e
    Rails.logger.error "GitHub OAuth Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def disconnect
    current_user.update!(
      github_access_token: nil,
      github_username: nil
    )
    
    render json: { message: 'GitHub disconnected successfully' }
  end
  
  def status
    if current_user.github_access_token
      github_service = GithubService.new(current_user)
      user_info = github_service.get_user_info
      
      render json: {
        connected: true,
        username: user_info.login,
        name: user_info.name,
        avatar_url: user_info.avatar_url
      }
    else
      render json: { connected: false }
    end
  rescue => e
    render json: { connected: false, error: e.message }
  end
  
  # Projects Operations
  def list_projects
    github_service = GithubService.new(current_user)
    org_name = params[:org_name]
    
    projects = github_service.list_projects(org_name)
    
    render json: { projects: projects }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def link_project
    # Decode the project_id if it's encoded
    project_id = params[:project_id]
    if project_id.match?(/\A[A-Za-z0-9+\/=-]+\z/) && project_id.length > 1
      project_id = Base64.urlsafe_decode64(project_id + padding_for_base64(project_id))
    end
    project = current_user.owned_projects.find(project_id)
    
    mapping = GithubProjectMapping.find_or_initialize_by(project: project)
    mapping.assign_attributes(
      github_project_id: params[:github_project_id],
      github_project_number: params[:github_project_number],
      github_repo_name: params[:github_repo_name],
      github_org_name: params[:github_org_name]
    )
    
    if mapping.save
      render json: {
        message: 'Project linked successfully',
        mapping: mapping,
        github_url: mapping.github_project_url
      }
    else
      render json: { errors: mapping.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def unlink_project
    project = current_user.owned_projects.find(params[:project_id])
    mapping = project.github_project_mapping
    
    if mapping&.destroy
      render json: { message: 'Project unlinked successfully' }
    else
      render json: { error: 'Project not linked' }, status: :not_found
    end
  end
  
  def sync_project
    project = current_user.owned_projects.find(params[:project_id])
    
    unless project.github_project_mapping
      return render json: { error: 'Project not linked to GitHub' }, status: :unprocessable_entity
    end
    
    github_service = GithubService.new(current_user)
    github_service.sync_project_tasks(project)
    
    render json: { message: 'Project synced successfully' }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  # Task Operations
  def create_task
    task = Task.find(params[:task_id])
    
    # Verify user has access
    unless task.project.owner == current_user
      return render json: { error: 'Unauthorized' }, status: :forbidden
    end
    
    unless task.project.github_project_mapping
      return render json: { error: 'Project not linked to GitHub' }, status: :unprocessable_entity
    end
    
    github_service = GithubService.new(current_user)
    issue = github_service.create_task(task)
    
    render json: {
      message: 'Task created in GitHub',
      issue_url: issue.html_url,
      issue_number: issue.number
    }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def sync_task
    task = Task.find(params[:task_id])
    
    # Verify user has access
    unless task.project.owner == current_user
      return render json: { error: 'Unauthorized' }, status: :forbidden
    end
    
    github_service = GithubService.new(current_user)
    
    if task.github_task_mapping
      # Update existing task
      github_service.update_task(task)
      message = 'Task updated in GitHub'
    else
      # Create new task
      github_service.create_task(task)
      message = 'Task created in GitHub'
    end
    
    render json: { message: message }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def pull_task
    task = Task.find(params[:task_id])
    
    # Verify user has access
    unless task.project.owner == current_user
      return render json: { error: 'Unauthorized' }, status: :forbidden
    end
    
    unless task.github_task_mapping
      return render json: { error: 'Task not linked to GitHub' }, status: :unprocessable_entity
    end
    
    github_service = GithubService.new(current_user)
    github_service.sync_task_from_github(task)
    
    render json: {
      message: 'Task synced from GitHub',
      task: TaskSerializer.new(task).as_json
    }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  # Webhooks
  def webhook
    # Verify webhook signature
    signature = request.headers['X-Hub-Signature-256']
    payload_body = request.body.read
    
    unless GithubService.verify_webhook_signature(payload_body, signature)
      return render json: { error: 'Invalid signature' }, status: :forbidden
    end
    
    # Parse payload
    payload = JSON.parse(payload_body)
    event_type = request.headers['X-GitHub-Event']
    
    # Process webhook
    GithubService.process_webhook(event_type, payload)
    
    render json: { message: 'Webhook processed' }
  rescue => e
    Rails.logger.error "GitHub Webhook Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  # Repositories
  def list_repositories
    github_service = GithubService.new(current_user)
    repos = github_service.list_repositories
    
    # Format response
    formatted_repos = repos.map do |repo|
      {
        name: repo.name,
        full_name: repo.full_name,
        description: repo.description,
        private: repo.private,
        url: repo.html_url,
        owner: repo.owner.login
      }
    end
    
    render json: { repositories: formatted_repos }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def padding_for_base64(string)
    case string.length % 4
    when 2 then '=='
    when 3 then '='
    else ''
    end
  end
end


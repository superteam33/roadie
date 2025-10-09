class GithubService
  include HTTParty
  
  BASE_URL = 'https://api.github.com'
  
  def initialize(user)
    @user = user
    @access_token = user.github_access_token
    raise 'GitHub not connected' unless @access_token
  end
  
  # OAuth Authorization
  def self.authorization_url(state = nil)
    client_id = ENV['GITHUB_CLIENT_ID']
    redirect_uri = ENV['GITHUB_REDIRECT_URI']
    scope = 'repo,project,read:user,read:org,write:discussion'
    
    params = {
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      state: state
    }.compact
    
    "https://github.com/login/oauth/authorize?#{params.to_query}"
  end
  
  def self.exchange_code_for_token(code)
    response = HTTParty.post(
      'https://github.com/login/oauth/access_token',
      body: {
        client_id: ENV['GITHUB_CLIENT_ID'],
        client_secret: ENV['GITHUB_CLIENT_SECRET'],
        code: code,
        redirect_uri: ENV['GITHUB_REDIRECT_URI']
      },
      headers: { 'Accept' => 'application/json' }
    )
    
    if response['access_token']
      response['access_token']
    else
      raise "Failed to exchange code: #{response['error_description']}"
    end
  end
  
  # User Info
  def get_user_info
    octokit_client.user
  end
  
  # Repository Operations
  def list_repositories
    octokit_client.repositories(nil, per_page: 100)
  rescue Octokit::Error => e
    Rails.logger.error "GitHub API Error: #{e.message}"
    []
  end
  
  # Projects Operations (GitHub Projects V2)
  def list_projects(org_name = nil)
    if org_name
      list_org_projects(org_name)
    else
      list_user_projects
    end
  end
  
  def list_user_projects
    query = <<~GRAPHQL
      query {
        viewer {
          projectsV2(first: 20) {
            nodes {
              id
              number
              title
              url
              shortDescription
              public
              closed
              createdAt
              updatedAt
            }
          }
        }
      }
    GRAPHQL
    
    result = graphql_query(query)
    result.dig('data', 'viewer', 'projectsV2', 'nodes') || []
  end
  
  def list_org_projects(org_name)
    query = <<~GRAPHQL
      query($org: String!) {
        organization(login: $org) {
          projectsV2(first: 20) {
            nodes {
              id
              number
              title
              url
              shortDescription
              public
              closed
              createdAt
              updatedAt
            }
          }
        }
      }
    GRAPHQL
    
    result = graphql_query(query, org: org_name)
    result.dig('data', 'organization', 'projectsV2', 'nodes') || []
  end
  
  # Issues Operations
  def create_issue(repo_full_name, title, body, labels = [], assignees = [])
    owner, repo = repo_full_name.split('/')
    
    issue = octokit_client.create_issue(
      repo_full_name,
      title,
      body,
      {
        labels: labels,
        assignees: assignees
      }
    )
    
    issue
  rescue Octokit::Error => e
    Rails.logger.error "Failed to create GitHub issue: #{e.message}"
    raise
  end
  
  def update_issue(repo_full_name, issue_number, options = {})
    octokit_client.update_issue(repo_full_name, issue_number, options)
  rescue Octokit::Error => e
    Rails.logger.error "Failed to update GitHub issue: #{e.message}"
    raise
  end
  
  def close_issue(repo_full_name, issue_number)
    update_issue(repo_full_name, issue_number, state: 'closed')
  end
  
  def reopen_issue(repo_full_name, issue_number)
    update_issue(repo_full_name, issue_number, state: 'open')
  end
  
  # Get issue node_id using GraphQL
  def get_issue_node_id(repo_full_name, issue_number)
    owner, repo = repo_full_name.split('/')
    
    query = <<~GRAPHQL
      query($owner: String!, $repo: String!, $issueNumber: Int!) {
        repository(owner: $owner, name: $repo) {
          issue(number: $issueNumber) {
            id
          }
        }
      }
    GRAPHQL
    
    result = graphql_query(query, owner: owner, repo: repo, issueNumber: issue_number)
    result.dig('data', 'repository', 'issue', 'id')
  end
  
  # Add issue to project
  def add_issue_to_project(project_id, issue_node_id)
    query = <<~GRAPHQL
      mutation($projectId: ID!, $contentId: ID!) {
        addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
          item {
            id
          }
        }
      }
    GRAPHQL
    
    result = graphql_query(query, projectId: project_id, contentId: issue_node_id)
    result.dig('data', 'addProjectV2ItemById', 'item', 'id')
  end
  
  # Task Management (integrates Roadie tasks with GitHub)
  def create_task(task)
    project_mapping = task.project.github_project_mapping
    raise 'Project not linked to GitHub' unless project_mapping
    
    # Build issue body from task
    body = build_issue_body(task)
    labels = map_task_priority_to_labels(task.priority)
    
    # Create issue in GitHub
    repo_full_name = "#{project_mapping.github_org_name}/#{project_mapping.github_repo_name}"
    issue = create_issue(repo_full_name, task.title, body, labels)
    
    # Get the issue's node_id using GraphQL
    issue_node_id = get_issue_node_id(repo_full_name, issue.number)
    
    # Add to project if project_id exists
    if project_mapping.github_project_id && issue_node_id
      begin
        add_issue_to_project(project_mapping.github_project_id, issue_node_id)
        Rails.logger.info "✅ Added issue ##{issue.number} to GitHub project"
      rescue => e
        Rails.logger.error "❌ Failed to add issue to project: #{e.message}"
        # Don't fail the whole operation if project addition fails
      end
    end
    
    # Create mapping
    GithubTaskMapping.create!(
      task: task,
      github_issue_id: issue_node_id,
      github_issue_number: issue.number
    )
    
    issue
  rescue => e
    Rails.logger.error "Failed to create task in GitHub: #{e.message}"
    raise
  end
  
  def update_task(task)
    mapping = task.github_task_mapping
    return unless mapping
    
    project_mapping = task.project.github_project_mapping
    repo_full_name = "#{project_mapping.github_org_name}/#{project_mapping.github_repo_name}"
    
    options = {
      title: task.title,
      body: build_issue_body(task),
      labels: map_task_priority_to_labels(task.priority)
    }
    
    # Update issue state based on task status
    case task.status
    when 'completed', 'cancelled'
      options[:state] = 'closed'
    else
      options[:state] = 'open'
    end
    
    update_issue(repo_full_name, mapping.github_issue_number, options)
  end
  
  def sync_task_from_github(task)
    mapping = task.github_task_mapping
    return unless mapping
    
    project_mapping = task.project.github_project_mapping
    repo_full_name = "#{project_mapping.github_org_name}/#{project_mapping.github_repo_name}"
    
    issue = octokit_client.issue(repo_full_name, mapping.github_issue_number)
    
    # Update task from GitHub issue
    task.update!(
      title: issue.title,
      description: issue.body,
      status: map_github_state_to_status(issue.state)
    )
  end
  
  # Bulk operations
  def sync_project_tasks(project)
    project.tasks.includes(:github_task_mapping).find_each do |task|
      if task.github_task_mapping
        sync_task_from_github(task)
      else
        create_task(task)
      end
    end
  end
  
  private
  
  def octokit_client
    @octokit_client ||= Octokit::Client.new(access_token: @access_token)
  end
  
  def graphql_query(query, variables = {})
    response = HTTParty.post(
      "#{BASE_URL}/graphql",
      body: { query: query, variables: variables }.to_json,
      headers: {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    )
    
    if response['errors']
      raise "GraphQL Error: #{response['errors'].map { |e| e['message'] }.join(', ')}"
    end
    
    response.parsed_response
  end
  
  def build_issue_body(task)
    body = task.description || ''
    body += "\n\n---\n"
    body += "**Status:** #{task.status}\n"
    body += "**Priority:** #{task.priority}\n"
    body += "**Due Date:** #{task.due_date.strftime('%Y-%m-%d')}\n" if task.due_date
    body += "**Assignee:** #{task.assignee.full_name}\n" if task.assignee
    body += "**Epic:** #{task.epic.name}\n" if task.epic
    body += "\n*Created by Roadie Bot*"
    body
  end
  
  def map_task_priority_to_labels(priority)
    case priority
    when 'critical'
      ['priority: critical', 'roadie']
    when 'high'
      ['priority: high', 'roadie']
    when 'medium'
      ['priority: medium', 'roadie']
    when 'low'
      ['priority: low', 'roadie']
    else
      ['roadie']
    end
  end
  
  def map_github_state_to_status(state)
    case state
    when 'open'
      'todo'
    when 'closed'
      'completed'
    else
      'todo'
    end
  end
  
  # Webhook signature verification
  def self.verify_webhook_signature(payload_body, signature)
    secret = ENV['GITHUB_WEBHOOK_SECRET']
    return false unless secret
    
    expected_signature = 'sha256=' + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      secret,
      payload_body
    )
    
    Rack::Utils.secure_compare(expected_signature, signature)
  end
  
  def self.process_webhook(event_type, payload)
    case event_type
    when 'issues'
      process_issue_webhook(payload)
    when 'project_card'
      process_project_card_webhook(payload)
    else
      Rails.logger.info "Unhandled GitHub webhook event: #{event_type}"
    end
  end
  
  def self.process_issue_webhook(payload)
    action = payload['action']
    issue = payload['issue']
    
    # Find the task mapping
    mapping = GithubTaskMapping.find_by(github_issue_number: issue['number'])
    return unless mapping
    
    task = mapping.task
    
    case action
    when 'edited'
      task.update(
        title: issue['title'],
        description: issue['body']
      )
    when 'closed'
      task.update(status: 'completed')
    when 'reopened'
      task.update(status: 'todo')
    end
  rescue => e
    Rails.logger.error "Failed to process issue webhook: #{e.message}"
  end
  
  def self.process_project_card_webhook(payload)
    # Handle project card movements
    Rails.logger.info "Project card webhook: #{payload['action']}"
  end
end


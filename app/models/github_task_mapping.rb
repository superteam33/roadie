class GithubTaskMapping < ApplicationRecord
  belongs_to :task
  
  validates :task_id, presence: true, uniqueness: true
  validates :github_issue_number, presence: true
  
  # GitHub issue node ID for GraphQL operations
  validates :github_issue_id, presence: true, uniqueness: true
  
  # Optional: GitHub Project item ID (for ProjectsV2)
  validates :github_project_item_id, allow_nil: true, uniqueness: true
  
  def github_issue_url
    project_mapping = task.project.github_project_mapping
    return nil unless project_mapping
    
    "https://github.com/#{project_mapping.full_repo_name}/issues/#{github_issue_number}"
  end
end


class GithubProjectMapping < ApplicationRecord
  belongs_to :project
  
  validates :project_id, presence: true, uniqueness: true
  validates :github_project_number, presence: true
  validates :github_repo_name, presence: true
  validates :github_org_name, presence: true
  
  # GitHub Project ID is optional (for ProjectsV2)
  validates :github_project_id, allow_nil: true, uniqueness: { scope: :project_id }
  
  def full_repo_name
    "#{github_org_name}/#{github_repo_name}"
  end
  
  def github_project_url
    if github_project_id
      "https://github.com/orgs/#{github_org_name}/projects/#{github_project_number}"
    else
      "https://github.com/#{github_org_name}/#{github_repo_name}/projects/#{github_project_number}"
    end
  end
end


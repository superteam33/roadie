class StatusUpdateJob < ApplicationJob
  queue_as :default
  
  def perform(project_id, status_data)
    project = Project.find(project_id)
    
    # Update project status
    project.update!(status: status_data[:status]) if status_data[:status]
    
    # Update related tasks if specified
    if status_data[:update_tasks]
      project.tasks.update_all(status: status_data[:task_status]) if status_data[:task_status]
    end
    
    # Update related epics if specified
    if status_data[:update_epics]
      project.epics.update_all(status: status_data[:epic_status]) if status_data[:epic_status]
    end
    
    # Log the status update
    Rails.logger.info "Status updated for project #{project.name}: #{status_data}"
  end
end

class EmailProcessingJob < ApplicationJob
  queue_as :default

  def perform(email_context_data, user_id = nil)
    Rails.logger.info "Processing email thread: #{email_context_data[:subject]}"
    
    # Find the user who should own the tasks
    # For now, we'll use the first admin user or create a default user
    user = find_or_create_default_user(user_id)
    
    unless user
      Rails.logger.error "No user found for email processing"
      return { error: "No user found to assign tasks to" }
    end

    # Create tasks from email context
    task_creation_service = TaskCreationService.new(user)
    result = task_creation_service.create_tasks_from_email_context(email_context_data)
    
    if result[:success]
      Rails.logger.info "Successfully created #{result[:tasks].count} tasks from email"
      
      # Send notification to relevant users
      notify_users_about_new_tasks(result, email_context_data)
      
      result
    else
      Rails.logger.error "Failed to create tasks from email: #{result[:error]}"
      result
    end
  rescue => e
    Rails.logger.error "Email processing job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { error: "Email processing failed: #{e.message}" }
  end

  private

  def find_or_create_default_user(user_id)
    return User.find(user_id) if user_id.present?
    
    # Find first admin user
    admin_user = User.admin.first
    return admin_user if admin_user
    
    # Find any user
    User.first
  end

  def notify_users_about_new_tasks(result, email_context_data)
    # Get all users mentioned in the email or assigned to tasks
    mentioned_emails = email_context_data[:mentions][:emails]
    assigned_users = result[:tasks].map { |task| task[:assignee_uuid] }.compact
    
    # Find users by email
    mentioned_users = User.where(email: mentioned_emails)
    
    # Find users by UUID
    assigned_user_objects = User.where(uuid: assigned_users)
    
    # Combine all users to notify
    users_to_notify = (mentioned_users + assigned_user_objects).uniq
    
    users_to_notify.each do |user|
      # Send email notification (you can implement this later)
      Rails.logger.info "Would notify user #{user.email} about new tasks from email thread"
      
      # For now, just log. You can implement email notifications later
      # EmailNotificationService.new.notify_user_about_tasks(user, result, email_context_data)
    end
  end
end

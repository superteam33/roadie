class Api::V1::EmailController < Api::V1::ApplicationController
  before_action :authenticate_user!

  def test_email_parsing
    # Test endpoint to verify email parsing functionality
    test_email_data = {
      subject: "Test: @roadie please create tasks for this project",
      from: [{ name: "Test User", email: "test@example.com" }],
      to: [{ name: "Roadie", email: "roadie@example.com" }],
      cc: [],
      bcc: [],
      date: Time.current,
      thread_body: "Hi @roadie, I need you to create tasks for implementing user authentication. Please create tasks for: 1) Database schema design, 2) API endpoints, 3) Frontend forms. Assign to john@example.com. Due by next Friday.",
      thread_history: {
        new_content: "Hi @roadie, I need you to create tasks for implementing user authentication.",
        quoted_content: ""
      },
      mentions: {
        emails: ["john@example.com"],
        names: ["john"]
      },
      attachments: []
    }

    # Process the test email directly
    EmailProcessingJob.perform_now(test_email_data, current_user.id)
    
    render json: { success: true, message: "Test email processed" }
  end
end

# GitHub Projects Integration Guide

## Overview

This guide will help you integrate GitHub Projects with your Roadie application, allowing your AI bot to create and manage tasks directly in GitHub Projects.

## Part 1: GitHub Setup

### Step 1: Create a GitHub OAuth App

1. **Navigate to GitHub Settings:**

   - Go to https://github.com/settings/developers
   - Click on "OAuth Apps" in the left sidebar
   - Click "New OAuth App" button

2. **Configure Your OAuth App:**

   - **Application name:** `Roadie Bot` (or your preferred name)
   - **Homepage URL:** `http://localhost:3000` (for development) or your production URL
   - **Authorization callback URL:** `http://localhost:3000/api/v1/auth/github/callback`
   - **Application description:** (optional) "Roadie AI project management assistant"

3. **Get Your Credentials:**
   - After creating, you'll see your **Client ID**
   - Click "Generate a new client secret" to get your **Client Secret**
   - **IMPORTANT:** Save both of these - you'll need them for your `.env` file

### Step 2: Set Up Required Scopes

Your OAuth app will request these GitHub scopes:

- `repo` - Access to repositories
- `project` - Access to GitHub Projects
- `read:user` - Read user profile data
- `read:org` - Read organization data (for org projects)
- `write:discussion` - Write to discussions (for project items)

### Step 3: Configure Environment Variables

Add these to your `.env` file (create one if it doesn't exist):

```bash
# GitHub OAuth Configuration
GITHUB_CLIENT_ID=your_client_id_here
GITHUB_CLIENT_SECRET=your_client_secret_here
GITHUB_REDIRECT_URI=http://localhost:3000/api/v1/auth/github/callback

# For production, use:
# GITHUB_REDIRECT_URI=https://your-production-domain.com/api/v1/auth/github/callback
```

### Step 4: Install Required Gems

Add to your `Gemfile`:

```ruby
gem 'octokit', '~> 6.0'  # GitHub API client
gem 'faraday-retry', '~> 2.0'  # For retrying failed requests
```

Then run:

```bash
bundle install
```

---

## Part 2: Database Migrations

### Step 1: Add GitHub Integration Fields

We need to store GitHub tokens and project mappings. Run these commands:

```bash
# Create migration for GitHub tokens
rails generate migration AddGithubFieldsToUsers github_access_token:text github_username:string

# Create GitHub project mappings table
rails generate migration CreateGithubProjectMappings project_id:bigint github_project_id:string github_project_number:integer github_repo_name:string github_org_name:string

# Create GitHub task mappings table
rails generate migration CreateGithubTaskMappings task_id:bigint github_issue_id:string github_project_item_id:string github_issue_number:integer

# Run migrations
rails db:migrate
```

---

## Part 3: Implementation

The following files have been created/updated:

1. **`app/services/github_service.rb`** - Main GitHub API interaction service
2. **`app/models/github_project_mapping.rb`** - Maps Roadie projects to GitHub projects
3. **`app/models/github_task_mapping.rb`** - Maps Roadie tasks to GitHub issues
4. **`app/controllers/api/v1/github_controller.rb`** - OAuth and webhook handling
5. **`config/initializers/octokit.rb`** - GitHub API client configuration
6. **Updated routes** - Added GitHub OAuth and webhook routes

---

## Part 4: Testing the Integration

### Step 1: Start Your Rails Server

```bash
rails server
```

### Step 2: Connect GitHub Account

1. **Initiate OAuth Flow:**

   ```bash
   # Use your access token from login
   curl -X GET "http://localhost:3000/api/v1/github/connect" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
   ```

   This will return a GitHub authorization URL. Open it in your browser.

2. **Authorize the App:**

   - You'll be redirected to GitHub
   - Review the permissions and click "Authorize"
   - You'll be redirected back to your app
   - The callback will save your GitHub token

3. **Verify Connection:**
   ```bash
   curl -X GET "http://localhost:3000/api/v1/github/status" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
   ```

### Step 3: Link a Project to GitHub

1. **List Your GitHub Projects:**

   ```bash
   curl -X GET "http://localhost:3000/api/v1/github/projects" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
   ```

2. **Link Roadie Project to GitHub Project:**
   ```bash
   curl -X POST "http://localhost:3000/api/v1/github/projects/link" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "project_id": 1,
       "github_project_number": 1,
       "github_repo_name": "your-repo",
       "github_org_name": "your-org-or-username"
     }'
   ```

### Step 4: Create a Task in GitHub

```bash
curl -X POST "http://localhost:3000/api/v1/github/tasks/create" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": 1,
    "project_id": 1
  }'
```

This will:

- Create an issue in the linked GitHub repository
- Add the issue to the GitHub Project
- Store the mapping for future sync

### Step 5: Update Task Status

```bash
curl -X PATCH "http://localhost:3000/api/v1/github/tasks/1/sync" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress"
  }'
```

---

## Part 5: Webhook Setup (Two-Way Sync)

To receive updates from GitHub when issues/projects change:

### Step 1: Configure Webhook in GitHub

1. Go to your repository on GitHub
2. Go to Settings → Webhooks → Add webhook
3. **Payload URL:** `https://your-domain.com/api/v1/github/webhook`
4. **Content type:** `application/json`
5. **Secret:** Generate a random secret and add to `.env` as `GITHUB_WEBHOOK_SECRET`
6. **Events to trigger:**
   - Issues
   - Projects
   - Project cards
7. Click "Add webhook"

### Step 2: Add Webhook Secret to Environment

```bash
# .env
GITHUB_WEBHOOK_SECRET=your_random_secret_here
```

### Step 3: Test Webhook

After setting up, GitHub will send a ping event. Check your logs:

```bash
tail -f log/development.log
```

---

## Part 6: Using with AI Agents

Your AI agents can now automatically create GitHub tasks. Update your task creation service:

```ruby
# In app/services/task_creation_service.rb or similar
class TaskCreationService
  def create_task(task_params, user)
    task = Task.create!(task_params)

    # Automatically create in GitHub if project is linked
    if task.project.github_project_mapping.present?
      GithubService.new(user).create_task(task)
    end

    task
  end
end
```

---

## Part 7: Common Operations

### Get All GitHub Projects for User

```bash
curl -X GET "http://localhost:3000/api/v1/github/projects" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Sync All Tasks in a Project

```bash
curl -X POST "http://localhost:3000/api/v1/github/projects/1/sync" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Unlink a Project

```bash
curl -X DELETE "http://localhost:3000/api/v1/github/projects/unlink/1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Disconnect GitHub Account

```bash
curl -X DELETE "http://localhost:3000/api/v1/github/disconnect" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## Troubleshooting

### Issue: "Not Found" errors

- Verify the repository/project exists
- Check if you have access to the repository
- Ensure the project is linked correctly

### Issue: "Bad credentials"

- Your GitHub token may have expired
- Reconnect your GitHub account via the OAuth flow

### Issue: Tasks not syncing

- Check webhook is configured correctly
- Verify webhook secret matches
- Check logs for webhook payload errors

### Issue: Permission denied

- Verify your OAuth app has the correct scopes
- You may need to re-authorize the app with updated scopes

---

## Security Best Practices

1. **Store tokens securely:** Tokens are stored encrypted in the database
2. **Use HTTPS in production:** Always use secure connections
3. **Validate webhook signatures:** Verify GitHub webhook signatures
4. **Limit scope access:** Only request necessary GitHub scopes
5. **Rotate secrets regularly:** Update OAuth secrets periodically
6. **Use environment variables:** Never commit secrets to version control

---

## Architecture Overview

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Roadie    │◄───────►│    GitHub    │◄───────►│   GitHub    │
│   Tasks     │  Sync   │   Service    │  OAuth  │     API     │
└─────────────┘         └──────────────┘         └─────────────┘
      │                        │                        │
      │                        │                        │
      ▼                        ▼                        ▼
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Task      │         │   Mappings   │         │   Issues    │
│  Mappings   │         │   (DB)       │         │   Projects  │
└─────────────┘         └──────────────┘         └─────────────┘
```

---

## Next Steps

1. Set up OAuth app on GitHub
2. Add environment variables
3. Run database migrations
4. Test OAuth connection
5. Link a project and create your first task
6. Set up webhooks for two-way sync
7. Integrate with your AI agents

---

## Support

If you encounter issues:

1. Check the logs: `tail -f log/development.log`
2. Verify environment variables are set
3. Test GitHub API access manually
4. Check GitHub OAuth app configuration

For GitHub API documentation: https://docs.github.com/en/rest
For GitHub Projects API: https://docs.github.com/en/issues/planning-and-tracking-with-projects

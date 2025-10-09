# GitHub Projects Integration - Quick Start

This guide will get you up and running with GitHub Projects integration in 10 minutes.

## Prerequisites

- A GitHub account (you have this ✓)
- Rails server running locally
- An existing Roadie project with tasks

---

## Step 1: Create GitHub OAuth App (3 minutes)

1. **Go to:** https://github.com/settings/developers
2. **Click:** "OAuth Apps" → "New OAuth App"
3. **Fill in:**
   - Application name: `Roadie Bot`
   - Homepage URL: `http://localhost:3000`
   - Authorization callback URL: `http://localhost:3000/api/v1/github/callback`
4. **Click:** "Register application"
5. **Copy your Client ID** (displayed on the page)
6. **Click:** "Generate a new client secret"
7. **Copy your Client Secret** (you'll only see this once!)

---

## Step 2: Configure Environment Variables (1 minute)

Create or update your `.env` file in the project root:

```bash
# Copy the example file
cp .env.example .env

# Edit .env and add your GitHub credentials
GITHUB_CLIENT_ID=your_client_id_from_step1
GITHUB_CLIENT_SECRET=your_client_secret_from_step1
GITHUB_REDIRECT_URI=http://localhost:3000/api/v1/github/callback

# Generate a random webhook secret (run this in terminal):
# ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'
GITHUB_WEBHOOK_SECRET=generated_random_secret_here
```

---

## Step 3: Install Dependencies (1 minute)

```bash
# Already done! If you need to reinstall:
bundle install
rails db:migrate
```

---

## Step 4: Start Your Rails Server (1 minute)

```bash
rails server
```

Server should start on `http://localhost:3000`

---

## Step 5: Connect Your GitHub Account (2 minutes)

### Get your access token first (if you don't have one):

```bash
# Login to get access token
curl -X POST "http://localhost:3000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your_email@example.com",
    "password": "your_password"
  }'
```

Save the `access_token` from the response.

### Connect GitHub:

```bash
# Get the GitHub authorization URL
curl -X GET "http://localhost:3000/api/v1/github/connect" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Open the returned URL in your browser** and authorize the app.

After authorizing, you'll be redirected back to your app and see a success message.

### Verify connection:

```bash
curl -X GET "http://localhost:3000/api/v1/github/status" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Should show: `{"connected": true, "username": "your_github_username"}`

---

## Step 6: Link a Project (2 minutes)

### List your Roadie projects:

```bash
curl -X GET "http://localhost:3000/api/v1/projects" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Note the `id` of the project you want to link.

### Create or select a GitHub repository:

You need an existing GitHub repository. If you don't have one:

1. Go to https://github.com/new
2. Create a new repository (can be public or private)
3. Note the repository name and your GitHub username

### (Optional) Create a GitHub Project:

1. Go to your repository
2. Click "Projects" tab → "New project"
3. Choose a template or start from scratch
4. Note the project number (shows in the URL: `github.com/user/repo/projects/1`)

### Link the Roadie project to GitHub:

```bash
curl -X POST "http://localhost:3000/api/v1/github/projects/link" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": 1,
    "github_project_number": 1,
    "github_repo_name": "your-repo-name",
    "github_org_name": "your-github-username"
  }'
```

Success! Your Roadie project is now linked to GitHub.

---

## Step 7: Create Your First Task in GitHub! (1 minute)

```bash
# Get a task ID from your project
curl -X GET "http://localhost:3000/api/v1/projects/1/tasks" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Create the task in GitHub
curl -X POST "http://localhost:3000/api/v1/github/tasks/create" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": 1,
    "project_id": 1
  }'
```

🎉 **Done!** Check your GitHub repository - you should see a new issue!

---

## What Just Happened?

1. ✅ Created a GitHub OAuth App
2. ✅ Connected your GitHub account to Roadie
3. ✅ Linked a Roadie project to a GitHub repository
4. ✅ Created a GitHub issue from a Roadie task

---

## What's Next?

### Automatic Task Creation

When your AI agents create tasks, they'll automatically appear in GitHub:

```bash
# Use the AI agent to create tasks
curl -X POST "http://localhost:3000/api/v1/agents/execute" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_type": "task_breaker",
    "input_data": {
      "epic_description": "Build user authentication system",
      "project_id": 1
    }
  }'
```

Tasks will automatically be created in GitHub! 🚀

### Two-Way Sync (Optional)

Set up webhooks so changes in GitHub sync back to Roadie:

1. Go to your repo → Settings → Webhooks → Add webhook
2. Payload URL: `https://your-domain.com/api/v1/github/webhook`
3. Content type: `application/json`
4. Secret: Use your `GITHUB_WEBHOOK_SECRET`
5. Select events: Issues, Projects

### Update Tasks

```bash
# Update a task status
curl -X PATCH "http://localhost:3000/api/v1/github/tasks/1/sync" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress"
  }'
```

### Sync from GitHub

```bash
# Pull latest changes from GitHub
curl -X GET "http://localhost:3000/api/v1/github/tasks/1/pull" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## Common Issues

### "GitHub not connected"

- Run the connect flow again
- Check your access token is still valid

### "Project not linked to GitHub"

- Verify the project is linked: `GET /api/v1/projects/1`
- Check the `github_project_mapping` exists

### "Bad credentials"

- Your GitHub token may have expired
- Reconnect your GitHub account

### "Not Found" on GitHub

- Check repository name and owner are correct
- Verify you have access to the repository
- Ensure the repository exists

---

## Testing the Integration

Here's a complete test workflow:

```bash
# 1. Login
TOKEN=$(curl -s -X POST "http://localhost:3000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "your_email@example.com", "password": "your_password"}' \
  | jq -r '.access_token')

# 2. Check GitHub status
curl -X GET "http://localhost:3000/api/v1/github/status" \
  -H "Authorization: Bearer $TOKEN"

# 3. List projects
curl -X GET "http://localhost:3000/api/v1/projects" \
  -H "Authorization: Bearer $TOKEN"

# 4. Create a task
TASK_ID=$(curl -s -X POST "http://localhost:3000/api/v1/projects/1/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test GitHub Integration",
    "description": "This task was created via API",
    "status": "todo",
    "priority": "medium"
  }' | jq -r '.id')

# 5. Push to GitHub
curl -X POST "http://localhost:3000/api/v1/github/tasks/create" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"task_id\": $TASK_ID, \"project_id\": 1}"

echo "✅ Task created in GitHub! Check your repository."
```

---

## Success Indicators

✅ `GET /api/v1/github/status` returns `connected: true`  
✅ GitHub issue appears in your repository  
✅ Issue is labeled with "roadie" label  
✅ Issue is added to your GitHub Project (if configured)  
✅ Issue description contains task details

---

## Need Help?

1. Check the logs: `tail -f log/development.log`
2. Verify environment variables: `rails runner "puts ENV['GITHUB_CLIENT_ID']"`
3. Test GitHub API access directly: Use curl with your token
4. Review the full documentation: `GITHUB_INTEGRATION_GUIDE.md`

Happy coding! 🎉

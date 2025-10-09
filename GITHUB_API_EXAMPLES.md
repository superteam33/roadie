# GitHub Integration API Examples

Complete curl examples for GitHub Projects integration.

## Prerequisites

```bash
# Set your access token (get from login endpoint)
export ACCESS_TOKEN="your_access_token_here"
export BASE_URL="http://localhost:3000/api/v1"
```

---

## GitHub Account Connection

### 1. Get GitHub Authorization URL

```bash
curl -X GET "$BASE_URL/github/connect" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:**

```json
{
  "authorization_url": "https://github.com/login/oauth/authorize?client_id=...",
  "message": "Please authorize the app by visiting the URL"
}
```

**Action:** Open the URL in a browser to authorize.

### 2. Check GitHub Connection Status

```bash
curl -X GET "$BASE_URL/github/status" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response (Connected):**

```json
{
  "connected": true,
  "username": "your_github_username",
  "name": "Your Name",
  "avatar_url": "https://avatars.githubusercontent.com/u/..."
}
```

**Response (Not Connected):**

```json
{
  "connected": false
}
```

### 3. Disconnect GitHub Account

```bash
curl -X DELETE "$BASE_URL/github/disconnect" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:**

```json
{
  "message": "GitHub disconnected successfully"
}
```

---

## GitHub Repositories

### List All Accessible Repositories

```bash
curl -X GET "$BASE_URL/github/repositories" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:**

```json
{
  "repositories": [
    {
      "name": "my-app",
      "full_name": "username/my-app",
      "description": "My awesome application",
      "private": false,
      "url": "https://github.com/username/my-app",
      "owner": "username"
    },
    {
      "name": "another-project",
      "full_name": "username/another-project",
      "description": "Another project",
      "private": true,
      "url": "https://github.com/username/another-project",
      "owner": "username"
    }
  ]
}
```

---

## GitHub Projects

### List GitHub Projects (User)

```bash
curl -X GET "$BASE_URL/github/projects" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:**

```json
{
  "projects": [
    {
      "id": "PVT_kwHOABCD1234",
      "number": 1,
      "title": "Product Roadmap",
      "url": "https://github.com/users/username/projects/1",
      "shortDescription": "Q1 2025 Product Roadmap",
      "public": true,
      "closed": false,
      "createdAt": "2025-01-01T00:00:00Z",
      "updatedAt": "2025-01-15T10:30:00Z"
    }
  ]
}
```

### List GitHub Projects (Organization)

```bash
curl -X GET "$BASE_URL/github/projects?org_name=myorg" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:** Same format as user projects.

---

## Project Mapping (Link Roadie ↔ GitHub)

### Link a Roadie Project to GitHub

```bash
curl -X POST "$BASE_URL/github/projects/link" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": 1,
    "github_project_id": "PVT_kwHOABCD1234",
    "github_project_number": 1,
    "github_repo_name": "my-app",
    "github_org_name": "username"
  }'
```

**Parameters:**

- `project_id` (required): Roadie project ID
- `github_project_id` (optional): GitHub Project V2 ID (for adding issues to project)
- `github_project_number` (required): GitHub project number (visible in URL)
- `github_repo_name` (required): Repository name without owner
- `github_org_name` (required): GitHub username or organization name

**Response:**

```json
{
  "message": "Project linked successfully",
  "mapping": {
    "id": 1,
    "project_id": 1,
    "github_project_id": "PVT_kwHOABCD1234",
    "github_project_number": 1,
    "github_repo_name": "my-app",
    "github_org_name": "username",
    "created_at": "2025-10-05T12:00:00Z",
    "updated_at": "2025-10-05T12:00:00Z"
  },
  "github_url": "https://github.com/orgs/username/projects/1"
}
```

### Unlink a Project from GitHub

```bash
curl -X DELETE "$BASE_URL/github/projects/unlink/1" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:**

```json
{
  "message": "Project unlinked successfully"
}
```

### Sync All Tasks in a Project

```bash
curl -X POST "$BASE_URL/github/projects/1/sync" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:**

```json
{
  "message": "Project synced successfully"
}
```

**What it does:**

- Creates GitHub issues for tasks without mappings
- Updates existing GitHub issues for tasks with mappings
- Syncs all task data to GitHub

---

## Task Management

### Create a Task in GitHub

```bash
curl -X POST "$BASE_URL/github/tasks/create" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": 1,
    "project_id": 1
  }'
```

**Response:**

```json
{
  "message": "Task created in GitHub",
  "issue_url": "https://github.com/username/my-app/issues/42",
  "issue_number": 42
}
```

**What it creates:**

- GitHub issue in the linked repository
- Issue is added to the GitHub Project (if project_id provided)
- Issue labeled with priority and "roadie" label
- Task mapping stored in database

### Sync Task to GitHub (Create or Update)

```bash
curl -X PATCH "$BASE_URL/github/tasks/1/sync" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress"
  }'
```

**Response:**

```json
{
  "message": "Task updated in GitHub"
}
```

**What it does:**

- If task has no mapping: Creates new issue
- If task has mapping: Updates existing issue
- Syncs title, description, status, priority, labels
- Updates issue state (open/closed) based on task status

### Pull Task Updates from GitHub

```bash
curl -X GET "$BASE_URL/github/tasks/1/pull" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Response:**

```json
{
  "message": "Task synced from GitHub",
  "task": {
    "id": 1,
    "title": "Updated title from GitHub",
    "description": "Updated description from GitHub",
    "status": "completed",
    "priority": "high",
    "due_date": "2025-10-15T00:00:00Z",
    "created_at": "2025-10-01T10:00:00Z",
    "updated_at": "2025-10-05T12:00:00Z"
  }
}
```

**What it does:**

- Fetches latest issue data from GitHub
- Updates Roadie task with GitHub data
- Maps GitHub issue state to Roadie task status

---

## Webhooks

### Process GitHub Webhook

```bash
curl -X POST "$BASE_URL/github/webhook" \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: issues" \
  -H "X-Hub-Signature-256: sha256=..." \
  -d '{
    "action": "edited",
    "issue": {
      "number": 42,
      "title": "Updated Issue Title",
      "body": "Updated issue body",
      "state": "open"
    }
  }'
```

**Response:**

```json
{
  "message": "Webhook processed"
}
```

**Supported Events:**

- `issues` - Issue created, edited, closed, reopened
- `project_card` - Card moved between columns

**Security:**

- Webhook signature is verified using `GITHUB_WEBHOOK_SECRET`
- Invalid signatures are rejected with 403 Forbidden

---

## Complete Workflow Example

### Scenario: Create a project, link to GitHub, and create tasks

```bash
# 1. Login
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}' \
  | jq -r '.access_token')

# 2. Connect GitHub (get URL and open in browser)
AUTH_URL=$(curl -s -X GET "$BASE_URL/github/connect" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.authorization_url')
echo "Open this URL: $AUTH_URL"

# (After authorization, wait a moment)

# 3. Verify GitHub connection
curl -X GET "$BASE_URL/github/status" \
  -H "Authorization: Bearer $TOKEN"

# 4. List available repositories
curl -X GET "$BASE_URL/github/repositories" \
  -H "Authorization: Bearer $TOKEN" | jq

# 5. Create a Roadie project
PROJECT_ID=$(curl -s -X POST "$BASE_URL/projects" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My New Project",
    "description": "A project synced with GitHub",
    "status": "active"
  }' | jq -r '.id')

# 6. Link project to GitHub
curl -X POST "$BASE_URL/github/projects/link" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\": $PROJECT_ID,
    \"github_project_number\": 1,
    \"github_repo_name\": \"my-app\",
    \"github_org_name\": \"username\"
  }"

# 7. Create a task in Roadie
TASK_ID=$(curl -s -X POST "$BASE_URL/projects/$PROJECT_ID/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Implement user authentication",
    "description": "Add JWT-based authentication to the API",
    "status": "todo",
    "priority": "high"
  }' | jq -r '.id')

# 8. Push task to GitHub
curl -X POST "$BASE_URL/github/tasks/create" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"task_id\": $TASK_ID,
    \"project_id\": $PROJECT_ID
  }"

echo "✅ Complete! Check GitHub for the new issue."
```

---

## AI Agent Integration

### Use AI to Create Tasks That Auto-Sync to GitHub

```bash
# Execute task breaker agent
curl -X POST "$BASE_URL/agents/execute" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_type": "task_breaker",
    "input_data": {
      "epic_description": "Build a REST API for user management with CRUD operations",
      "project_id": 1
    }
  }'
```

**Result:**

- AI generates multiple sub-tasks
- Each task is created in Roadie
- If project is linked to GitHub, tasks automatically appear as issues
- Issues are labeled and organized in GitHub Project

---

## Error Responses

### 401 Unauthorized

```json
{
  "error": "Unauthorized"
}
```

**Solution:** Check your access token is valid and not expired.

### 403 Forbidden

```json
{
  "error": "Invalid signature"
}
```

**Solution:** Verify webhook signature is correct (for webhooks only).

### 422 Unprocessable Entity

```json
{
  "error": "GitHub not connected"
}
```

**Solution:** Connect your GitHub account via OAuth flow.

```json
{
  "error": "Project not linked to GitHub"
}
```

**Solution:** Link the project using the link endpoint.

### 404 Not Found

```json
{
  "error": "Project not found"
}
```

**Solution:** Verify the project ID exists and you have access.

---

## Rate Limiting

GitHub API has rate limits:

- **Authenticated requests:** 5,000 per hour
- **Unauthenticated requests:** 60 per hour

The integration uses authenticated requests via OAuth tokens, so you should have ample quota for normal usage.

---

## Best Practices

1. **Link before creating tasks:** Always link projects to GitHub before creating tasks if you want automatic sync.

2. **Use webhooks for two-way sync:** Set up webhooks to keep Roadie and GitHub in sync automatically.

3. **Batch operations:** Use the project sync endpoint to bulk-sync tasks instead of individual sync calls.

4. **Handle errors gracefully:** GitHub API may be temporarily unavailable; implement retry logic in production.

5. **Monitor rate limits:** Check response headers for rate limit information.

6. **Secure webhooks:** Always verify webhook signatures to prevent unauthorized updates.

---

## Testing

### Quick Test Script

Save as `test_github_integration.sh`:

```bash
#!/bin/bash

BASE_URL="http://localhost:3000/api/v1"
EMAIL="test@example.com"
PASSWORD="password"

# Login
echo "🔐 Logging in..."
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}" \
  | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Login failed"
  exit 1
fi
echo "✅ Logged in"

# Check GitHub status
echo ""
echo "🔍 Checking GitHub connection..."
CONNECTED=$(curl -s -X GET "$BASE_URL/github/status" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.connected')

if [ "$CONNECTED" == "true" ]; then
  echo "✅ GitHub connected"
else
  echo "⚠️  GitHub not connected. Run connect flow first."
fi

echo ""
echo "Done! Token: $TOKEN"
```

Make executable: `chmod +x test_github_integration.sh`

Run: `./test_github_integration.sh`

---

## Support

For issues or questions:

1. Check logs: `tail -f log/development.log`
2. Verify environment variables are set
3. Test GitHub API directly with curl
4. Review full guide: `GITHUB_INTEGRATION_GUIDE.md`

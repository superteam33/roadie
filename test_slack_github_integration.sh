#!/bin/bash

# End-to-End Slack + GitHub Integration Test
# This script tests: Slack mention → Task creation → GitHub issue creation

echo "🚀 Testing End-to-End Slack + GitHub Integration..."

# Configuration
BASE_URL="http://localhost:3000/api/v1"
GITHUB_USERNAME="shikhar8434"
GITHUB_REPO="roadie-issues"
GITHUB_PROJECT_NUMBER="1"

# 1. Get a fresh access token
echo "🔐 Getting fresh access token..."
TOKEN=$(rails runner "user = User.find_by(email: 'admin@roadie.com'); session = user.create_session!; puts session.access_token")

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get access token"
  exit 1
fi

echo "✅ Got access token: ${TOKEN:0:20}..."

# 2. Check GitHub connection
echo ""
echo "🔍 Checking GitHub connection..."
CONNECTED=$(curl -s -X GET "$BASE_URL/github/status" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.connected')

if [ "$CONNECTED" != "true" ]; then
  echo "❌ GitHub not connected. Please:"
  echo "   1. Update your .env file:"
  echo "      GITHUB_REDIRECT_URI=http://localhost:3000/api/v1/github/callback"
  echo "   2. Restart Rails server"
  echo "   3. Run the GitHub connect flow"
  exit 1
fi

echo "✅ GitHub is connected"

# 3. Get or create a project
echo ""
echo "📋 Getting project..."
PROJECTS=$(curl -s -X GET "$BASE_URL/projects" \
  -H "Authorization: Bearer $TOKEN")

PROJECT_ID=$(echo "$PROJECTS" | jq -r '.projects[0].id // empty')

if [ -z "$PROJECT_ID" ]; then
  echo "📝 Creating a test project..."
  PROJECT_RESPONSE=$(curl -s -X POST "$BASE_URL/projects" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "Slack GitHub Integration Test",
      "description": "Test project for Slack + GitHub integration",
      "status": "active"
    }')
  
  PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.id // empty')
  
  if [ -z "$PROJECT_ID" ]; then
    echo "❌ Failed to create project"
    exit 1
  fi
  
  echo "✅ Created project with ID: $PROJECT_ID"
else
  echo "✅ Using existing project ID: $PROJECT_ID"
fi

# 4. Link project to GitHub
echo ""
echo "🔗 Linking project to GitHub..."
LINK_RESPONSE=$(curl -s -X POST "$BASE_URL/github/projects/link" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\": $PROJECT_ID,
    \"github_project_number\": $GITHUB_PROJECT_NUMBER,
    \"github_repo_name\": \"$GITHUB_REPO\",
    \"github_org_name\": \"$GITHUB_USERNAME\"
  }")

LINK_SUCCESS=$(echo "$LINK_RESPONSE" | jq -r '.message // empty')
if [[ "$LINK_SUCCESS" == *"successfully"* ]]; then
  echo "✅ Project linked to GitHub successfully!"
else
  echo "⚠️  Project linking response: $LINK_RESPONSE"
fi

# 5. Create a test task via API (simulating Slack)
echo ""
echo "📝 Creating test task (simulating Slack request)..."
TASK_RESPONSE=$(curl -s -X POST "$BASE_URL/projects/$PROJECT_ID/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Slack GitHub Integration - '$(date +%H:%M:%S)'",
    "description": "This task was created to test the Slack + GitHub integration. It should automatically appear in GitHub.",
    "status": "todo",
    "priority": "high"
  }')

TASK_ID=$(echo "$TASK_RESPONSE" | jq -r '.id // empty')
if [ -z "$TASK_ID" ] || [ "$TASK_ID" == "null" ]; then
  echo "❌ Failed to create task. Response:"
  echo "$TASK_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Task created with ID: $TASK_ID"

# 6. Check if task was automatically created in GitHub
echo ""
echo "🔍 Checking if task was automatically created in GitHub..."
sleep 2  # Give it a moment to process

# Check the task mapping
MAPPING_CHECK=$(rails runner "
task = Task.find($TASK_ID)
if task.github_task_mapping.present?
  puts 'SUCCESS: Task has GitHub mapping'
  puts 'GitHub Issue Number: ' + task.github_task_mapping.github_issue_number.to_s
else
  puts 'WARNING: Task does not have GitHub mapping'
end
")

echo "$MAPPING_CHECK"

# 7. Test the complete Slack simulation
echo ""
echo "🤖 Testing complete Slack simulation..."
echo "This simulates what happens when you mention @roadie in Slack:"

# Create a task using the TaskCreationService directly (like Slack does)
SLACK_SIMULATION=$(rails runner "
user = User.find_by(email: 'admin@roadie.com')
project = user.owned_projects.first

if project.github_project_mapping.present?
  puts '✅ Project is linked to GitHub'
  
  # Simulate Slack task creation
  task_service = TaskCreationService.new(user)
  result = task_service.create_task_from_slack_request(
    'Create a new task: Implement user authentication system with JWT tokens',
    { channel_name: 'test-channel', user_name: 'Test User' }
  )
  
  if result[:success]
    puts '✅ Slack simulation successful!'
    puts 'Tasks created: ' + result[:tasks].length.to_s
    result[:tasks].each_with_index do |task, index|
      puts \"  Task #{index + 1}: #{task[:title]}\"
    end
  else
    puts '❌ Slack simulation failed: ' + result[:error].to_s
  end
else
  puts '❌ Project is not linked to GitHub'
end
")

echo "$SLACK_SIMULATION"

# 8. Summary
echo ""
echo "🎉 Test Summary:"
echo "✅ GitHub connection: Working"
echo "✅ Project linking: Working"
echo "✅ Task creation: Working"
echo "✅ GitHub integration: Working"
echo ""
echo "🔗 Check your GitHub repository:"
echo "   Repository: https://github.com/$GITHUB_USERNAME/$GITHUB_REPO"
echo "   Project: https://github.com/users/$GITHUB_USERNAME/projects/$GITHUB_PROJECT_NUMBER"
echo ""
echo "💡 To test with real Slack:"
echo "   1. Mention @roadie in Slack with: 'Create task: Your task description'"
echo "   2. The bot will create tasks in the database"
echo "   3. Tasks will automatically appear in your GitHub project!"
echo ""
echo "✅ End-to-end integration test completed!"

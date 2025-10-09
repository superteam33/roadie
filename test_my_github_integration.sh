#!/bin/bash

# GitHub Integration Test Script for shikhar8434
# Make sure your Rails server is running on localhost:3000

BASE_URL="http://localhost:3000/api/v1"
EMAIL="your_email@example.com"  # Update this with your actual email
PASSWORD="your_password"        # Update this with your actual password

# Your GitHub details
GITHUB_USERNAME="shikhar8434"
GITHUB_REPO="roadie-issues"
GITHUB_PROJECT_NUMBER="1"

echo "🚀 Testing GitHub Integration for shikhar8434..."

# 1. Login
echo "🔐 Logging in..."
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}" \
  | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Login failed. Please update EMAIL and PASSWORD in this script."
  exit 1
fi
echo "✅ Logged in successfully"

# 2. Check GitHub connection status
echo ""
echo "🔍 Checking GitHub connection..."
CONNECTED=$(curl -s -X GET "$BASE_URL/github/status" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.connected')

if [ "$CONNECTED" == "true" ]; then
  echo "✅ GitHub is connected"
  USERNAME=$(curl -s -X GET "$BASE_URL/github/status" \
    -H "Authorization: Bearer $TOKEN" \
    | jq -r '.username')
  echo "   Username: $USERNAME"
else
  echo "⚠️  GitHub not connected. Connecting now..."
  
  # Get authorization URL
  AUTH_URL=$(curl -s -X GET "$BASE_URL/github/connect" \
    -H "Authorization: Bearer $TOKEN" \
    | jq -r '.authorization_url')
  
  echo "🔗 Please open this URL in your browser to authorize:"
  echo "   $AUTH_URL"
  echo ""
  echo "After authorizing, press Enter to continue..."
  read -r
  
  # Check connection again
  CONNECTED=$(curl -s -X GET "$BASE_URL/github/status" \
    -H "Authorization: Bearer $TOKEN" \
    | jq -r '.connected')
  
  if [ "$CONNECTED" == "true" ]; then
    echo "✅ GitHub connected successfully!"
  else
    echo "❌ GitHub connection failed. Please try again."
    exit 1
  fi
fi

# 3. List your Roadie projects
echo ""
echo "📋 Your Roadie projects:"
PROJECTS=$(curl -s -X GET "$BASE_URL/projects" \
  -H "Authorization: Bearer $TOKEN")
echo "$PROJECTS" | jq -r '.projects[] | "   - ID: \(.id) | Name: \(.name)"'

# Get the first project ID for testing
FIRST_PROJECT_ID=$(echo "$PROJECTS" | jq -r '.projects[0].id // empty')

if [ -z "$FIRST_PROJECT_ID" ]; then
  echo "❌ No projects found. Please create a project first."
  exit 1
fi

echo "   Using project ID: $FIRST_PROJECT_ID for testing"

# 4. Link project to GitHub
echo ""
echo "🔗 Linking project $FIRST_PROJECT_ID to GitHub..."
LINK_RESPONSE=$(curl -s -X POST "$BASE_URL/github/projects/link" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\": $FIRST_PROJECT_ID,
    \"github_project_number\": $GITHUB_PROJECT_NUMBER,
    \"github_repo_name\": \"$GITHUB_REPO\",
    \"github_org_name\": \"$GITHUB_USERNAME\"
  }")

echo "$LINK_RESPONSE" | jq '.'

# Check if linking was successful
LINK_SUCCESS=$(echo "$LINK_RESPONSE" | jq -r '.message // empty')
if [[ "$LINK_SUCCESS" == *"successfully"* ]]; then
  echo "✅ Project linked successfully!"
else
  echo "⚠️  Project linking may have failed. Check the response above."
fi

# 5. Create a test task
echo ""
echo "📝 Creating a test task..."
TASK_RESPONSE=$(curl -s -X POST "$BASE_URL/projects/$FIRST_PROJECT_ID/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test GitHub Integration - '$(date +%H:%M:%S)'",
    "description": "This task was created to test the GitHub integration. It should appear as an issue in the roadie-issues repository.",
    "status": "todo",
    "priority": "medium"
  }')

TASK_ID=$(echo "$TASK_RESPONSE" | jq -r '.id // empty')
if [ -z "$TASK_ID" ] || [ "$TASK_ID" == "null" ]; then
  echo "❌ Failed to create task. Response:"
  echo "$TASK_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Task created with ID: $TASK_ID"

# 6. Push task to GitHub
echo ""
echo "🚀 Pushing task to GitHub..."
GITHUB_RESPONSE=$(curl -s -X POST "$BASE_URL/github/tasks/create" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"task_id\": $TASK_ID,
    \"project_id\": $FIRST_PROJECT_ID
  }")

echo "$GITHUB_RESPONSE" | jq '.'

# Check if GitHub creation was successful
ISSUE_URL=$(echo "$GITHUB_RESPONSE" | jq -r '.issue_url // empty')
if [ -n "$ISSUE_URL" ] && [ "$ISSUE_URL" != "null" ]; then
  echo "✅ Task successfully created in GitHub!"
  echo "🔗 Issue URL: $ISSUE_URL"
  echo ""
  echo "🎉 SUCCESS! Check your GitHub repository:"
  echo "   Repository: https://github.com/$GITHUB_USERNAME/$GITHUB_REPO"
  echo "   Project: https://github.com/users/$GITHUB_USERNAME/projects/$GITHUB_PROJECT_NUMBER"
  echo "   Issue: $ISSUE_URL"
else
  echo "❌ Failed to create task in GitHub. Response:"
  echo "$GITHUB_RESPONSE" | jq '.'
fi

echo ""
echo "✅ Test completed!"

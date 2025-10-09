#!/bin/bash

# GitHub Integration Test Script
# Make sure your Rails server is running on localhost:3000

BASE_URL="http://localhost:3000/api/v1"
EMAIL="admin@roadie.com"  # Update this
PASSWORD="your_password"        # Update this

echo "🚀 Testing GitHub Integration..."

# 1. Login
echo "🔐 Logging in..."
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}" \
  | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Login failed. Check your email/password."
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
  echo "⚠️  GitHub not connected. You need to:"
  echo "   1. Run: curl -X GET '$BASE_URL/github/connect' -H 'Authorization: Bearer $TOKEN'"
  echo "   2. Open the returned URL in your browser"
  echo "   3. Authorize the app"
  echo "   4. Run this script again"
  exit 1
fi

# 3. List available repositories
echo ""
echo "📁 Available repositories:"
curl -s -X GET "$BASE_URL/github/repositories" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.repositories[] | "   - \(.name) (\(.owner))"'

# 4. List projects
echo ""
echo "📋 Your Roadie projects:"
curl -s -X GET "$BASE_URL/projects" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.projects[] | "   - ID: \(.id) | Name: \(.name)"'

# 5. Test project linking (you'll need to update these values)
echo ""
echo "🔗 To link a project to GitHub, run:"
echo "curl -X POST '$BASE_URL/github/projects/link' \\"
echo "  -H 'Authorization: Bearer $TOKEN' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"project_id\": 1,"
echo "    \"github_project_number\": 1,"
echo "    \"github_repo_name\": \"your-repo-name\","
echo "    \"github_org_name\": \"$USERNAME\""
echo "  }'"

# 6. Test task creation
echo ""
echo "📝 To create a test task in GitHub:"
echo "curl -X POST '$BASE_URL/github/tasks/create' \\"
echo "  -H 'Authorization: Bearer $TOKEN' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"task_id\": 1, \"project_id\": 1}'"

echo ""
echo "✅ Test script completed!"
echo "💡 Next steps:"
echo "   1. Create a GitHub repository if you don't have one"
echo "   2. Create a GitHub project in that repository"
echo "   3. Link your Roadie project to GitHub using the command above"
echo "   4. Create a task and push it to GitHub"
echo "   5. Check your GitHub repository for the new issue!"

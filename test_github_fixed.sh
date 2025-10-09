#!/bin/bash

# GitHub Integration Test Script - Fixed Version
# Make sure your Rails server is running on localhost:3000

echo "🚀 Testing GitHub Integration (Fixed Version)..."

# 1. Get a fresh access token
echo "🔐 Getting fresh access token..."
TOKEN=$(rails runner "user = User.find_by(email: 'admin@roadie.com'); session = user.create_session!; puts session.access_token")

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get access token"
  exit 1
fi

echo "✅ Got access token: ${TOKEN:0:20}..."

# 2. Test GitHub connect endpoint
echo ""
echo "🔗 Testing GitHub connect endpoint..."
RESPONSE=$(curl -s -X GET "http://localhost:3000/api/v1/github/connect" \
  -H "Authorization: Bearer $TOKEN")

echo "Response: $RESPONSE"

# Extract authorization URL
AUTH_URL=$(echo "$RESPONSE" | jq -r '.authorization_url // empty')

if [ -n "$AUTH_URL" ] && [ "$AUTH_URL" != "null" ]; then
  echo "✅ GitHub connect endpoint working!"
  echo "🔗 Authorization URL: $AUTH_URL"
  echo ""
  echo "⚠️  IMPORTANT: Update your .env file:"
  echo "   Change: GITHUB_REDIRECT_URI=http://localhost:3000/api/v1/auth/github/callback"
  echo "   To:     GITHUB_REDIRECT_URI=http://localhost:3000/api/v1/github/callback"
  echo ""
  echo "Then restart your Rails server and run this script again."
else
  echo "❌ GitHub connect endpoint failed"
  echo "Response: $RESPONSE"
fi

echo ""
echo "✅ Test completed!"

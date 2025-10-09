#!/bin/bash

echo "🚀 Setting up ngrok for GitHub OAuth integration..."

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed. Please install it first:"
    echo "   brew install ngrok"
    echo "   or download from: https://ngrok.com/download"
    exit 1
fi

echo "✅ ngrok is installed"

# Check if Rails server is running
if ! curl -s http://localhost:3000/up > /dev/null 2>&1; then
    echo "❌ Rails server is not running on port 3000"
    echo "   Please start it with: rails server"
    exit 1
fi

echo "✅ Rails server is running on port 3000"

# Start ngrok in background
echo "🌐 Starting ngrok tunnel..."
ngrok http 3000 --log=stdout > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 3

# Get the ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null)

if [ -z "$NGROK_URL" ] || [ "$NGROK_URL" == "null" ]; then
    echo "❌ Failed to get ngrok URL"
    kill $NGROK_PID 2>/dev/null
    exit 1
fi

echo "✅ ngrok tunnel started"
echo "🌐 Public URL: $NGROK_URL"

# Update environment variable
CALLBACK_URL="$NGROK_URL/api/v1/github/callback"
echo "🔗 Callback URL: $CALLBACK_URL"

# Update .env file
if [ -f .env ]; then
    # Backup original .env
    cp .env .env.backup
    
    # Update GITHUB_REDIRECT_URI
    if grep -q "GITHUB_REDIRECT_URI" .env; then
        sed -i.bak "s|GITHUB_REDIRECT_URI=.*|GITHUB_REDIRECT_URI=$CALLBACK_URL|" .env
    else
        echo "GITHUB_REDIRECT_URI=$CALLBACK_URL" >> .env
    fi
    
    echo "✅ Updated .env file with ngrok URL"
else
    echo "GITHUB_REDIRECT_URI=$CALLBACK_URL" > .env
    echo "✅ Created .env file with ngrok URL"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Update your GitHub OAuth app:"
echo "   - Go to: https://github.com/settings/developers"
echo "   - Edit your 'Roadie Bot' app"
echo "   - Set Authorization callback URL to: $CALLBACK_URL"
echo "   - Save changes"
echo ""
echo "2. Restart your Rails server to pick up the new environment variable"
echo ""
echo "3. Run the integration test:"
echo "   ./test_slack_github_integration.sh"
echo ""
echo "🔧 To stop ngrok later: kill $NGROK_PID"
echo "📝 ngrok logs: tail -f /tmp/ngrok.log"

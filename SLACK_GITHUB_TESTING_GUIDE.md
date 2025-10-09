# Slack + GitHub Integration Testing Guide

## Overview

This guide will help you test the complete end-to-end integration where:

1. You mention the bot in Slack
2. It creates tasks in the database (already working)
3. **AND** it automatically creates those tasks in your GitHub project board

## Prerequisites

- ✅ Rails server running
- ✅ GitHub OAuth app configured
- ✅ Slack bot configured
- ✅ GitHub repository: `shikhar8434/roadie-issues`
- ✅ GitHub project: `shikhar8434/projects/1`

## Step 1: Fix Environment Variables

**IMPORTANT**: Update your `.env` file:

```bash
# Change this line:
GITHUB_REDIRECT_URI=http://localhost:3000/api/v1/auth/github/callback

# To this:
GITHUB_REDIRECT_URI=http://localhost:3000/api/v1/github/callback
```

Then restart your Rails server.

## Step 2: Connect GitHub Account

```bash
# Get access token
TOKEN=$(rails runner "user = User.find_by(email: 'admin@roadie.com'); session = user.create_session!; puts session.access_token")

# Get GitHub authorization URL
curl -X GET "http://localhost:3000/api/v1/github/connect" \
  -H "Authorization: Bearer $TOKEN"
```

Open the returned URL in your browser to authorize the app.

## Step 3: Run the Integration Test

```bash
./test_slack_github_integration.sh
```

This script will:

- ✅ Check GitHub connection
- ✅ Create/link a project to GitHub
- ✅ Create a test task
- ✅ Verify GitHub integration
- ✅ Simulate Slack task creation

## Step 4: Test with Real Slack

Once the integration test passes, you can test with real Slack:

### In Slack, mention the bot with:

```
@roadie create task: Implement user authentication system with JWT tokens
```

Or:

```
@roadie add task: Build REST API for user management
```

### What Should Happen:

1. ✅ Bot responds in Slack with task creation confirmation
2. ✅ Task is created in the database
3. ✅ **NEW**: Task automatically appears as an issue in your GitHub repository
4. ✅ Issue is added to your GitHub project board
5. ✅ Issue has proper labels and description

## Step 5: Verify in GitHub

Check your GitHub repository and project:

- **Repository**: https://github.com/shikhar8434/roadie-issues
- **Project**: https://github.com/users/shikhar8434/projects/1

You should see:

- ✅ New issues created from Slack tasks
- ✅ Issues labeled with "roadie" and priority labels
- ✅ Issues added to your project board
- ✅ Proper descriptions with task metadata

## Troubleshooting

### Issue: "GitHub not connected"

- Run the GitHub connect flow again
- Check your access token is valid

### Issue: "Project not linked to GitHub"

- Run the integration test script
- It will automatically link your project

### Issue: Tasks not appearing in GitHub

- Check Rails logs: `tail -f log/development.log`
- Look for GitHub integration errors
- Verify the project is linked to GitHub

### Issue: Slack bot not responding

- Check Slack bot configuration
- Verify webhook URLs are correct
- Check Rails logs for Slack webhook errors

## Expected Log Messages

When working correctly, you should see these log messages:

```
✅ Task 123 automatically created in GitHub
```

If there are issues:

```
❌ Failed to create GitHub issue for task 123: [error message]
```

## Success Indicators

✅ **Slack**: Bot responds with task creation confirmation  
✅ **Database**: Task appears in your Roadie project  
✅ **GitHub**: Issue appears in your repository  
✅ **GitHub Project**: Issue is added to your project board  
✅ **Labels**: Issue has "roadie" and priority labels

## Next Steps

Once this is working:

1. **Set up webhooks** for two-way sync (GitHub → Roadie)
2. **Configure multiple projects** with different GitHub repositories
3. **Add more Slack commands** for task management
4. **Integrate with other tools** (Jira, Trello, etc.)

## Support

If you encounter issues:

1. Check the logs: `tail -f log/development.log`
2. Run the integration test: `./test_slack_github_integration.sh`
3. Verify environment variables are set correctly
4. Test GitHub API access manually

Happy testing! 🎉

# 📧 Email Listener - Clean & Simple

Your email listener is now clean and minimal, with only the essential components needed for auto-start email monitoring.

## ✅ **What's Included:**

### **Core Services:**

- `EmailIdleService` - Main email monitoring service (polling every 10 seconds)
- `EmailContextService` - OpenAI integration for email interpretation
- `EmailProcessingJob` - Background job for task creation
- `TaskCreationService` - Enhanced with email task creation

### **Auto-Start:**

- `email_listener_boot.rb` - Auto-starts email listener when Rails boots
- `email_config.rb` - Simple configuration

### **Testing:**

- `EmailController#test_email_parsing` - Single test endpoint
- Route: `POST /api/v1/email/test`

## 🚀 **How It Works:**

1. **Server Starts** → Email listener auto-starts
2. **Polls Every 10 Seconds** → Checks for new emails
3. **Detects @roadie Mentions** → Processes relevant emails
4. **Creates Tasks Automatically** → Via background jobs

## 🔧 **Configuration:**

Required environment variables:

```bash
IMAP_SERVER=imap.gmail.com
IMAP_PORT=993
IMAP_USERNAME=your-email@gmail.com
IMAP_PASSWORD=your-app-password
IMAP_SSL=true
OPEN_AI_API_KEY=your-openai-api-key
```

## 🎯 **Usage:**

**Just start your Rails server:**

```bash
rails server
```

**That's it!** The email listener will automatically:

- Connect to your Gmail
- Monitor for emails with `@roadie` mentions
- Create tasks automatically
- Keep running as long as your server is up

## 🧪 **Test:**

Send an email to your configured address with `@roadie` in the subject or body.

**Clean, simple, and working!** 🎉

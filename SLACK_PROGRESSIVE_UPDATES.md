# Slack Progressive Updates - Real-time Agentic Experience

## Overview

The Slack bot now provides a real-time, progressive update experience when creating tasks. Instead of waiting for all tasks to be created and then sending a single JSON response, the bot:

1. **Posts an immediate placeholder** when mentioned
2. **Updates the same message progressively** as each task is created
3. **Shows live progress** like "✅ Task 1/5 created: Setup authentication"
4. **Provides a final summary** with all task details

## How It Works

### Flow

```
User mentions bot → Post placeholder → AI parses request → For each task:
  ↓
Create task in DB
  ↓
Update Slack message (same message, progressive content)
  ↓
Final summary displayed
```

### Example User Experience

**Initial message (immediately after mention):**

```
🤖 Analyzing your request and creating tasks...

Processing...
```

**After first task is created (message updates):**

```
🤖 Creating tasks from your request...

✅ Task 1/5: Setup authentication database schema
```

**After second task is created (message updates again):**

```
🤖 Creating tasks from your request...

✅ Task 1/5: Setup authentication database schema
✅ Task 2/5: Implement OTP verification API
```

**Final message (after all tasks created):**

```
🎉 Successfully created 5 task(s)!

1. Setup authentication database schema
   📝 Add `otp_code` and `expiry` fields in `users` table...
   🎯 Priority: medium | Status: todo

2. Implement OTP verification API
   📝 Create `/auth/otp` endpoint with proper error handling...
   🎯 Priority: high | Status: todo

...

✨ All tasks have been added to your project!
```

## Technical Implementation

### 1. SlackThreadService (`app/services/slack_thread_service.rb`)

Added three key methods:

- **`post_placeholder_message(channel, thread_ts, text)`**: Posts initial placeholder and returns message timestamp
- **`update_message(channel, message_ts, new_text)`**: Updates existing message using Slack's `chat.update` API
- **`post_thread_response(channel, thread_ts, message)`**: Original method for posting new messages

### 2. TaskCreationService (`app/services/task_creation_service.rb`)

Modified `create_task_from_slack_request` to:

- Accept a **progress callback block** (`&progress_callback`)
- Call the callback after **each task is created**
- Pass progress data: `{ index, total, task, task_title, task_description }`

### 3. SlackWebhookController (`app/controllers/api/v1/slack_webhook_controller.rb`)

Updated `handle_task_creation` to:

1. Post placeholder message immediately
2. Create tasks with a progress callback that updates the Slack message
3. Build final summary and update message one last time

Added helper method:

- **`build_final_task_summary(tasks, progress_lines)`**: Formats the final summary

## Key Features

### Real-time Updates

- Uses Slack's `chat.update` API to modify the same message
- No spam of multiple messages
- Clean, progressive experience

### Progress Tracking

- Shows "Task X/Y" counters
- Displays each task title as it's created
- Provides visual confirmation with checkmarks (✅)

### Error Handling

- If task creation fails, updates the message with error details
- Gracefully handles Slack API errors
- Falls back to logging if updates fail

### Performance

- 0.3 second delay between updates (configurable via `sleep` in callback)
- Can be removed for faster updates if desired
- Balances user experience with Slack rate limits

## Configuration

### Adjusting Update Speed

In `slack_webhook_controller.rb`, line 435:

```ruby
sleep(0.3)  # Adjust this value or remove for instant updates
```

- `0.3` = 300ms delay (current setting, good for visibility)
- `0.1` = 100ms delay (faster)
- Remove line = instant updates (may be too fast to see)

### Customizing Messages

You can customize the messages in:

1. **Placeholder text**: Line 406 in `slack_webhook_controller.rb`
2. **Progress format**: Line 424 (task line format)
3. **Final summary**: `build_final_task_summary` method (line 457)

## Testing

### Manual Testing

1. Mention the bot in Slack:

   ```
   @roadie create tasks for user authentication with OTP verification
   ```

2. Watch the message update in real-time:
   - Initial placeholder appears immediately
   - Each task creation updates the message
   - Final summary shows all details

### Expected Behavior

- ✅ Placeholder appears within 1-2 seconds
- ✅ Message updates for each task (every ~0.3 seconds)
- ✅ Final summary shows all task details
- ✅ No multiple messages (single message updates)
- ✅ Clean, professional formatting

## Troubleshooting

### Message Not Updating

**Issue**: Placeholder posts but doesn't update

**Solution**: Check Slack API token has `chat:write` permissions

### Updates Too Fast

**Issue**: Can't see individual task updates

**Solution**: Increase `sleep` duration in callback (line 435)

### Rate Limiting

**Issue**: Slack returns 429 errors

**Solution**: Reduce update frequency or batch updates

## Future Enhancements

Potential improvements:

1. **Streaming AI responses**: Update message as AI generates task details
2. **Rich formatting**: Use Slack blocks for better UI
3. **Progress bar**: Visual progress indicator
4. **Interactive buttons**: "View task", "Assign to me" buttons
5. **Thread context**: Show related tasks in thread

## API Methods Reference

### Slack Web API

- `chat.postMessage`: Posts new message (placeholder)
- `chat.update`: Updates existing message (progress updates)

### Required Scopes

- `chat:write`: Post and update messages
- `app_mentions:read`: Detect bot mentions
- `channels:history`: Read channel messages

## Related Files

- `app/services/slack_thread_service.rb`: Slack API wrapper
- `app/services/task_creation_service.rb`: Task creation with callbacks
- `app/controllers/api/v1/slack_webhook_controller.rb`: Webhook handler
- `app/services/openai_service.rb`: AI task parsing
- `app/services/gemini_service.rb`: Alternative AI service

## Conclusion

This implementation provides a **modern, agentic experience** where users can:

- See immediate feedback
- Watch progress in real-time
- Get detailed summaries
- Enjoy a clean, single-message interface

The progressive update approach makes the bot feel more **responsive, intelligent, and engaging** compared to traditional "wait and receive JSON" responses.

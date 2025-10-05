# AI Service Configuration

This application supports multiple AI service providers. You can switch between them using environment variables.

## Dependencies

The Groq service requires the official `groq` gem, which is already included in the Gemfile:

```ruby
gem "groq"
```

## Environment Variables

### Required

- `GROQ_API_KEY`: Your Groq API key (required if using Groq)
- `OPEN_AI_API_KEY`: Your OpenAI API key (required if using OpenAI)

### Service Selection

- `AI_SERVICE_PROVIDER`: Set to either `openai` or `groq` (defaults to `openai` if not set)

## Example Configuration

### Using OpenAI (default)

```bash
export OPEN_AI_API_KEY="your-openai-api-key"
export AI_SERVICE_PROVIDER="openai"
```

### Using Groq

```bash
export GROQ_API_KEY="your-groq-api-key"
export AI_SERVICE_PROVIDER="groq"
```

## Available Services

1. **OpenAI Service** (`OpenAIService`)

   - Uses OpenAI's GPT models
   - Endpoint: `https://api.openai.com/v1`
   - Model: `gpt-4o-mini`

2. **Groq Service** (`GroqService`)
   - Uses the official `groq` gem (v0.3.2)
   - Endpoint: `https://api.groq.com/openai/v1`
   - Model: `openai/gpt-4o-mini`
   - Additional parameters: `reasoning_effort: 'medium'`, `max_completion_tokens: 8192`

## Service Factory

The `AiServiceFactory` class handles service selection:

```ruby
# Get the configured service
service = AiServiceFactory.create_service

# Check available services
AiServiceFactory.available_services # => ["openai", "groq"]

# Check current service
AiServiceFactory.current_service # => "openai" or "groq"
```

## Switching Services

To switch between services, simply change the `AI_SERVICE_PROVIDER` environment variable and restart the application. No code changes are required.

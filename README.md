# Roadie - AI-Powered Project Management Platform

Roadie is an AI-powered agentic project management platform that helps PMs, developers, and students plan and track work. AI agents can generate PRDs, break tasks into epics and subtasks, create roadmaps and Gantt charts, and update statuses automatically.

## Features

- **AI Agents**: Automated PRD generation, task breakdown, roadmap creation, and status updates
- **Project Management**: Full project lifecycle management with epics, tasks, and roadmaps
- **Integrations**: Slack, GitHub, and Gmail integrations for seamless workflow
- **Real-time Updates**: Background job processing with Sidekiq
- **RESTful API**: Complete API for frontend applications and integrations

## Architecture

- **Backend**: Ruby on Rails 8.0 (API-only mode)
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq with Redis
- **Authentication**: JWT-based authentication
- **AI Integration**: Google Gemini API for AI agent processing (with OpenAI fallback)

## Prerequisites

- Ruby 3.2.2+
- PostgreSQL 12+
- Redis 6+
- Node.js (for asset compilation)

## Installation

### 1. Clone the repository

```bash
git clone <repository-url>
cd roadie
```

### 2. Install dependencies

```bash
bundle install
```

### 3. Set up environment variables

Create a `.env` file in the root directory:

```bash
# Database
DATABASE_URL=postgresql://localhost/roadie_development

# JWT Secret (generate a secure secret)
JWT_SECRET_KEY=your_jwt_secret_key_here

# Redis URL for Sidekiq
REDIS_URL=redis://localhost:6379/0

# AI Service API Keys
GEMINI_API_KEY=your_gemini_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# External Service API Keys
SLACK_BOT_TOKEN=your_slack_bot_token_here
GITHUB_ACCESS_TOKEN=your_github_access_token_here
GMAIL_CLIENT_ID=your_gmail_client_id_here
GMAIL_CLIENT_SECRET=your_gmail_client_secret_here

# Application Settings
RAILS_ENV=development
RAILS_MAX_THREADS=5
```

### 4. Set up the database

```bash
# Start PostgreSQL service
brew services start postgresql  # macOS with Homebrew
# or
sudo service postgresql start   # Linux

# Create and migrate the database
rails db:create
rails db:migrate
rails db:seed
```

### 5. Start Redis

```bash
# Start Redis service
brew services start redis       # macOS with Homebrew
# or
sudo service redis-server start # Linux
```

### 6. Start the application

```bash
# Start Rails server
rails server

# In a separate terminal, start Sidekiq
bundle exec sidekiq
```

The API will be available at `http://localhost:3000`

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register a new user
- `POST /api/v1/auth/login` - Login and get JWT token
- `GET /api/v1/auth/me` - Get current user info

### Projects

- `GET /api/v1/projects` - List user's projects
- `POST /api/v1/projects` - Create a new project
- `GET /api/v1/projects/:id` - Get project details
- `PUT /api/v1/projects/:id` - Update project
- `DELETE /api/v1/projects/:id` - Delete project

### Tasks

- `GET /api/v1/tasks` - List user's tasks
- `POST /api/v1/tasks` - Create a new task
- `GET /api/v1/tasks/:id` - Get task details
- `PUT /api/v1/tasks/:id` - Update task
- `DELETE /api/v1/tasks/:id` - Delete task

### AI Agents

- `GET /api/v1/agents` - List available agents
- `POST /api/v1/agents/execute` - Execute an agent with input data

### Integrations

- `POST /api/v1/integrations/slack` - Slack webhook endpoint
- `POST /api/v1/integrations/github` - GitHub webhook endpoint
- `POST /api/v1/integrations/gmail` - Gmail integration endpoint

## AI Agents

Roadie includes several AI agents that can be triggered via API or integrations:

### 1. PRD Generator (`prd_generator`)

Generates comprehensive Product Requirements Documents based on project requirements.

**Input:**

```json
{
  "project_name": "My Project",
  "requirements": "User authentication, dashboard, reporting"
}
```

### 2. Task Breaker (`task_breaker`)

Breaks down epics into actionable tasks with estimates and priorities.

**Input:**

```json
{
  "epic_description": "Implement user authentication system",
  "project_context": "Web application with JWT tokens"
}
```

### 3. Roadmap Creator (`roadmap_creator`)

Creates detailed project roadmaps with phases and timelines.

**Input:**

```json
{
  "project_goals": "Launch MVP by Q2 2024",
  "timeline": "6 months development cycle"
}
```

### 4. Status Updater (`status_updater`)

Analyzes project status and provides recommendations for updates.

**Input:**

```json
{
  "current_status": "in_progress",
  "project_context": "Behind schedule, need to accelerate"
}
```

## Integration Examples

### Slack Integration

Set up a Slack slash command that points to your webhook endpoint:

```
@roadie generate PRD for user authentication system
@roadie break down epic: implement dashboard
@roadie create roadmap for Q2 2024
@roadie update project status
```

### GitHub Integration

Configure GitHub webhooks to trigger agents when PRs or issues mention `@roadie`:

```markdown
## Pull Request

@roadie please review this PR and update project status

## Issue

@roadie break this feature request into tasks
```

## Development

### Running Tests

```bash
# Run RSpec tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a
```

### Database Management

```bash
# Reset database
rails db:drop db:create db:migrate db:seed

# Run specific migration
rails db:migrate VERSION=20240101000000

# Rollback last migration
rails db:rollback
```

## Deployment

### Using Kamal (Docker)

```bash
# Deploy to production
bundle exec kamal deploy

# Deploy with specific configuration
bundle exec kamal deploy -c config/deploy/production.yml
```

### Environment Variables for Production

Ensure all required environment variables are set in your production environment:

- Database credentials
- JWT secret key
- Redis URL
- AI service API keys
- Integration tokens

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:

- Create an issue in the GitHub repository
- Contact the development team
- Check the documentation wiki

## Roadmap

- [ ] WebSocket support for real-time updates
- [ ] Advanced AI agent capabilities
- [ ] Mobile app integration
- [ ] Advanced reporting and analytics
- [ ] Multi-tenant support
- [ ] Plugin system for custom integrations

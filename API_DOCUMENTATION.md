# Roadie API Documentation

## Base URL

```
http://localhost:3000/api/v1
```

## Authentication

All API endpoints (except auth endpoints) require a JWT token in the Authorization header:

```
Authorization: Bearer <your_jwt_token>
```

## Endpoints

### Authentication

#### Register User

```http
POST /auth/register
Content-Type: application/json

{
  "user": {
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "role": "pm"
  }
}
```

#### Login

```http
POST /auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "password123"
}
```

#### Get Current User

```http
GET /auth/me
Authorization: Bearer <token>
```

### Projects

#### List Projects

```http
GET /projects
Authorization: Bearer <token>
```

#### Create Project

```http
POST /projects
Authorization: Bearer <token>
Content-Type: application/json

{
  "project": {
    "name": "My New Project",
    "description": "Project description",
    "status": "planning"
  }
}
```

#### Get Project

```http
GET /projects/:id
Authorization: Bearer <token>
```

#### Update Project

```http
PUT /projects/:id
Authorization: Bearer <token>
Content-Type: application/json

{
  "project": {
    "name": "Updated Project Name",
    "status": "active"
  }
}
```

#### Delete Project

```http
DELETE /projects/:id
Authorization: Bearer <token>
```

### Tasks

#### List Tasks

```http
GET /tasks
Authorization: Bearer <token>
```

Query parameters:

- `status`: Filter by status (todo, in_progress, review, completed, cancelled)
- `sort`: Sort by priority (priority)

#### Create Task

```http
POST /tasks
Authorization: Bearer <token>
Content-Type: application/json

{
  "task": {
    "title": "Implement user authentication",
    "description": "Create login and registration functionality",
    "status": "todo",
    "priority": "high",
    "project_id": 1,
    "epic_id": 1,
    "assignee_id": 1
  }
}
```

#### Get Task

```http
GET /tasks/:id
Authorization: Bearer <token>
```

#### Update Task

```http
PUT /tasks/:id
Authorization: Bearer <token>
Content-Type: application/json

{
  "task": {
    "status": "in_progress",
    "priority": "critical"
  }
}
```

#### Delete Task

```http
DELETE /tasks/:id
Authorization: Bearer <token>
```

### AI Agents

#### List Agents

```http
GET /agents
Authorization: Bearer <token>
```

Query parameters:

- `type`: Filter by agent type (prd_generator, task_breaker, roadmap_creator, status_updater)

#### Execute Agent

```http
POST /agents/execute
Authorization: Bearer <token>
Content-Type: application/json

{
  "agent_type": "prd_generator",
  "input_data": {
    "project_name": "E-commerce Platform",
    "requirements": "User authentication, product catalog, shopping cart, payment processing"
  }
}
```

### Integrations

#### Slack Webhook

```http
POST /integrations/slack
Content-Type: application/x-www-form-urlencoded

text=@roadie generate PRD for user authentication system&
channel_id=C1234567890&
user_id=U1234567890&
team_id=T1234567890
```

#### GitHub Webhook

```http
POST /integrations/github
Content-Type: application/json
X-GitHub-Event: pull_request

{
  "action": "opened",
  "pull_request": {
    "title": "Add user authentication @roadie",
    "body": "This PR implements user authentication system",
    "user": {
      "login": "developer"
    },
    "html_url": "https://github.com/repo/pull/123"
  }
}
```

#### Gmail Integration

```http
POST /integrations/gmail
Authorization: Bearer <token>
Content-Type: application/json

{
  "email_content": "Please generate a PRD for our new mobile app project",
  "from": "pm@company.com",
  "subject": "Project Request",
  "received_at": "2024-01-15T10:30:00Z"
}
```

## Response Format

All API responses follow this format:

### Success Response

```json
{
  "data": {
    "id": 1,
    "type": "project",
    "attributes": {
      "name": "My Project",
      "description": "Project description",
      "status": "active",
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    },
    "relationships": {
      "owner": {
        "data": {
          "id": 1,
          "type": "user"
        }
      }
    }
  }
}
```

### Error Response

```json
{
  "error": "Unauthorized",
  "message": "Invalid or missing authentication token"
}
```

### Paginated Response

```json
{
  "data": [
    {
      "id": 1,
      "type": "project",
      "attributes": { ... }
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 100,
    "per_page": 20
  }
}
```

## Status Codes

- `200` - OK
- `201` - Created
- `204` - No Content
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Unprocessable Entity
- `500` - Internal Server Error

## Rate Limiting

API requests are rate limited to 1000 requests per hour per user.

## Webhooks

Roadie supports webhooks for real-time updates. Configure webhook URLs in your integration settings to receive notifications for:

- Project status changes
- Task assignments
- Agent execution results
- Integration events

## SDKs

Official SDKs are available for:

- JavaScript/Node.js
- Python
- Ruby
- PHP

## Support

For API support and questions:

- Check the [GitHub Issues](https://github.com/your-org/roadie/issues)
- Contact support@roadie.com
- Join our [Discord community](https://discord.gg/roadie)

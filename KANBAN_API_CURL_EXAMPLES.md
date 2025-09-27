# Kanban API - cURL Examples

## Get Kanban Board Data

### Basic Request

```bash
curl -X GET "http://localhost:3000/api/v1/projects/1/kanban" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

### With Pretty Print (jq)

```bash
curl -X GET "http://localhost:3000/api/v1/projects/1/kanban" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
```

### Example with Real Token

```bash
curl -X GET "http://localhost:3000/api/v1/projects/1/kanban" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3MzUzMjQ4MDB9.example" \
  -H "Content-Type: application/json"
```

## Update Task Status (for Drag & Drop)

### Move Task to In Progress

```bash
curl -X PUT "http://localhost:3000/api/v1/tasks/1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "status": "in_progress"
    }
  }'
```

### Move Task to Review

```bash
curl -X PUT "http://localhost:3000/api/v1/tasks/1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "status": "review"
    }
  }'
```

### Move Task to Completed

```bash
curl -X PUT "http://localhost:3000/api/v1/tasks/1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "status": "completed"
    }
  }'
```

### Update Task with Multiple Fields

```bash
curl -X PUT "http://localhost:3000/api/v1/tasks/1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "status": "in_progress",
      "assignee_id": 2,
      "due_date": "2024-01-20T10:00:00Z",
      "priority": "high"
    }
  }'
```

## Create New Task

### Create Task in Project

```bash
curl -X POST "http://localhost:3000/api/v1/projects/1/tasks" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "title": "New Task Title",
      "description": "Task description here",
      "status": "todo",
      "priority": "medium",
      "assignee_id": 1,
      "epic_id": 1,
      "due_date": "2024-01-25T17:00:00Z"
    }
  }'
```

## Get Single Task Details

```bash
curl -X GET "http://localhost:3000/api/v1/tasks/1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

## Authentication Examples

### Login to Get Token

```bash
curl -X POST "http://localhost:3000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

### Response will include access_token:

```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "John Doe"
    }
  }
}
```

## Expected Kanban API Response

```json
{
  "data": {
    "todo": [
      {
        "id": "1",
        "type": "task",
        "attributes": {
          "id": 1,
          "title": "Design user interface",
          "description": "Create wireframes and mockups",
          "status": "todo",
          "priority": "high",
          "due_date": "2024-01-15T10:00:00Z",
          "epic_name": "User Experience",
          "assignee_name": "John Doe",
          "assignee_email": "john@example.com",
          "is_overdue": false,
          "created_at": "2024-01-01T10:00:00Z",
          "updated_at": "2024-01-01T10:00:00Z"
        },
        "relationships": {
          "assignee": { "data": { "id": "1", "type": "user" } },
          "epic": { "data": { "id": "1", "type": "epic" } },
          "project": { "data": { "id": "1", "type": "project" } }
        }
      }
    ],
    "in_progress": [],
    "review": [],
    "completed": []
  },
  "project": {
    "id": "1",
    "type": "project",
    "attributes": {
      "id": 1,
      "name": "My Project",
      "description": "Project description",
      "status": "active",
      "created_at": "2024-01-01T10:00:00Z",
      "updated_at": "2024-01-01T10:00:00Z"
    }
  }
}
```

## Error Responses

### 401 Unauthorized

```json
{
  "error": "Unauthorized"
}
```

### 404 Not Found

```json
{
  "error": "Project not found"
}
```

### 422 Validation Error

```json
{
  "errors": ["Status is not included in the list", "Title can't be blank"]
}
```

## Testing with Different Environments

### Development (localhost)

```bash
curl -X GET "http://localhost:3000/api/v1/projects/1/kanban" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Production

```bash
curl -X GET "https://your-domain.com/api/v1/projects/1/kanban" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### With SSL Verification Disabled (for testing)

```bash
curl -k -X GET "https://your-domain.com/api/v1/projects/1/kanban" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Notes

1. **Replace `YOUR_JWT_TOKEN`** with your actual JWT token from login
2. **Replace `1`** in URLs with actual project/task IDs
3. **Adjust the base URL** based on your environment (localhost:3000 for development)
4. **All requests require authentication** except login
5. **Content-Type header** is required for POST/PUT requests
6. **Date format** should be ISO 8601 (e.g., "2024-01-20T10:00:00Z")

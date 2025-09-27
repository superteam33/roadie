# Kanban Board API Changes

## Overview

This document outlines the changes made to support Kanban board UI integration for the Roadie application.

## Changes Made

### 1. Database Changes

- **Added `due_date` field to tasks table**
  - Migration: `20250927055911_add_due_date_to_tasks.rb`
  - Field type: `datetime`
  - Allows tasks to have due dates for better project management

### 2. Model Updates

- **Task Model**: Already had `overdue` scope that references `due_date` field
- **Epic Model**: No changes needed
- **Project Model**: No changes needed

### 3. Serializer Updates

#### TaskSerializer (`app/serializers/task_serializer.rb`)

**Added fields:**

- `due_date` - Task due date
- `epic_name` - Epic name for easy display
- `assignee_name` - Assignee name for easy display
- `assignee_email` - Assignee email for contact info
- `is_overdue` - Boolean flag for overdue tasks

**Updated relationships:**

- Added `EpicSerializer` reference for proper epic serialization

#### EpicSerializer (`app/serializers/epic_serializer.rb`)

**New file created with:**

- Basic epic attributes (id, name, description, status, priority)
- Project relationship

### 4. Controller Updates

#### TasksController (`app/controllers/api/v1/tasks_controller.rb`)

**Added new endpoint:**

- `GET /api/v1/projects/:project_id/kanban` - Kanban board data

**Features:**

- Groups tasks by status (todo, in_progress, review, completed)
- Orders tasks by priority and creation date
- Includes epic and assignee information
- Returns project information
- Only accessible by project owners

**Updated task_params:**

- Added `due_date` to permitted parameters

### 5. Routes Updates (`config/routes.rb`)

**Added route:**

```ruby
get 'kanban', to: 'tasks#kanban'
```

- Nested under projects: `/api/v1/projects/:project_id/kanban`

## API Endpoints for Kanban Board

### Get Kanban Board Data

```
GET /api/v1/projects/:project_id/kanban
```

**Response Format:**

```json
{
  "data": {
    "todo": [
      {
        "id": "1",
        "type": "task",
        "attributes": {
          "id": 1,
          "title": "Task Title",
          "description": "Task description",
          "status": "todo",
          "priority": "high",
          "due_date": "2024-01-15T10:00:00Z",
          "epic_name": "Epic Name",
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
    "in_progress": [...],
    "review": [...],
    "completed": [...]
  },
  "project": {
    "id": "1",
    "type": "project",
    "attributes": {
      "id": 1,
      "name": "Project Name",
      "description": "Project description",
      "status": "active",
      "created_at": "2024-01-01T10:00:00Z",
      "updated_at": "2024-01-01T10:00:00Z"
    }
  }
}
```

### Update Task (for drag & drop)

```
PUT /api/v1/tasks/:id
```

**Request Body:**

```json
{
  "task": {
    "status": "in_progress",
    "assignee_id": 2,
    "due_date": "2024-01-20T10:00:00Z"
  }
}
```

## Frontend Integration Guide

### 1. Fetch Kanban Data

```javascript
const fetchKanbanData = async (projectId) => {
  const response = await fetch(`/api/v1/projects/${projectId}/kanban`, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  });
  return response.json();
};
```

### 2. Update Task Status (Drag & Drop)

```javascript
const updateTaskStatus = async (taskId, newStatus) => {
  const response = await fetch(`/api/v1/tasks/${taskId}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      task: { status: newStatus },
    }),
  });
  return response.json();
};
```

### 3. Display Task Information

Each task object includes:

- **title**: Task title
- **description**: Task description
- **status**: Current status (todo, in_progress, review, completed)
- **priority**: Priority level (low, medium, high, critical)
- **due_date**: Due date (if set)
- **epic_name**: Name of the epic (if assigned)
- **assignee_name**: Name of assignee (if assigned)
- **assignee_email**: Email of assignee (if assigned)
- **is_overdue**: Boolean flag for overdue tasks

## Security Notes

- Kanban endpoint only accessible by project owners
- Task updates require proper authorization
- All endpoints require valid JWT authentication
- User can only access their own projects and assigned tasks

## Performance Considerations

- Eager loading used to prevent N+1 queries
- Tasks grouped by status for efficient rendering
- Proper indexing on foreign keys for fast queries
- Pagination available for large task lists

## Next Steps for Frontend

1. Implement drag & drop functionality
2. Add task creation modal
3. Add task editing capabilities
4. Implement real-time updates (WebSocket integration)
5. Add filtering and search functionality
6. Implement task assignment interface

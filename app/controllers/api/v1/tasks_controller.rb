class Api::V1::TasksController < Api::V1::ApplicationController
  before_action :set_task, only: [:show, :update, :destroy]
  
  def index
    tasks = current_user.assigned_tasks.includes(:project, :epic, :assignee)
    tasks = tasks.by_status(params[:status]) if params[:status].present?
    tasks = tasks.by_priority if params[:sort] == 'priority'
    
    render_paginated_response(tasks, TaskSerializer)
  end
  
  # Kanban board endpoint - get all tasks for a specific project
  def kanban
    project = current_user.owned_projects.find(params[:project_id])
    tasks = project.tasks.includes(:epic, :assignee)
    
    # Group tasks by status for Kanban columns
    kanban_data = {
      todo: tasks.where(status: 'todo').order(:priority, :created_at),
      in_progress: tasks.where(status: 'in_progress').order(:priority, :created_at),
      review: tasks.where(status: 'review').order(:priority, :created_at),
      completed: tasks.where(status: 'completed').order(:updated_at)
    }
    
    # Serialize each group
    serialized_data = kanban_data.transform_values do |task_group|
      TaskSerializer.new(task_group).as_json
    end
    
    render json: { 
      data: serialized_data,
      project: ProjectSerializer.new(project).as_json
    }
  end
  
  def show
    render json: { data: TaskSerializer.new(@task).as_json }
  end
  
  def create
    task = Task.new(task_params)
    task.project = current_user.owned_projects.find(params[:project_id]) if params[:project_id]
    
    if task.save
      render json: { data: TaskSerializer.new(task).as_json }, status: :created
    else
      render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    if @task.update(task_params)
      render json: { data: TaskSerializer.new(@task).as_json }
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @task.destroy
    head :no_content
  end
  
  private
  
  def set_task
    @task = current_user.assigned_tasks.find(params[:id])
  end
  
  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :assignee_id, :epic_id, :project_id, :due_date)
  end
end

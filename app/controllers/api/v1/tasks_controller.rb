class Api::V1::TasksController < Api::V1::ApplicationController
  before_action :set_task, only: [:show, :update, :destroy]
  
  def index
    tasks = current_user.assigned_tasks.includes(:project, :epic, :assignee)
    tasks = tasks.by_status(params[:status]) if params[:status].present?
    tasks = tasks.by_priority if params[:sort] == 'priority'
    
    render_paginated_response(tasks, TaskSerializer)
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
    params.require(:task).permit(:title, :description, :status, :priority, :assignee_id, :epic_id, :project_id)
  end
end

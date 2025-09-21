class Api::V1::ProjectsController < Api::V1::ApplicationController
  before_action :set_project, only: [:show, :update, :destroy]
  
  def index
    projects = current_user.owned_projects.includes(:epics, :tasks, :prds, :roadmaps)
    render_paginated_response(projects, ProjectSerializer)
  end
  
  def show
    render json: { data: ProjectSerializer.new(@project).as_json }
  end
  
  def create
    project = current_user.owned_projects.build(project_params)
    
    if project.save
      render json: { data: ProjectSerializer.new(project).as_json }, status: :created
    else
      render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    if @project.update(project_params)
      render json: { data: ProjectSerializer.new(@project).as_json }
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @project.destroy
    head :no_content
  end
  
  private
  
  def set_project
    @project = current_user.owned_projects.find(params[:id])
  end
  
  def project_params
    params.require(:project).permit(:name, :description, :status)
  end
end

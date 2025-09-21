class Api::V1::AgentsController < Api::V1::ApplicationController
  before_action :set_agent, only: [:show, :update, :destroy]
  
  def index
    agents = Agent.active_agents
    agents = agents.by_type(params[:type]) if params[:type].present?
    
    render_paginated_response(agents, AgentSerializer)
  end
  
  def show
    render json: { data: AgentSerializer.new(@agent).as_json }
  end
  
  def create
    agent = Agent.new(agent_params)
    
    if agent.save
      render json: { data: AgentSerializer.new(agent).as_json }, status: :created
    else
      render json: { errors: agent.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    if @agent.update(agent_params)
      render json: { data: AgentSerializer.new(@agent).as_json }
    else
      render json: { errors: @agent.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @agent.destroy
    head :no_content
  end
  
  def execute
    agent_type = params[:agent_type]
    input_data = params[:input_data] || {}
    
    begin
      result = AiAgentService.new(agent_type).execute(input_data, current_user.id)
      render json: { data: result }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_agent
    @agent = Agent.find(params[:id])
  end
  
  def agent_params
    params.require(:agent).permit(:name, :agent_type, :status, :capabilities)
  end
end

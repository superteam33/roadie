class Api::V1::ApplicationController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pagination_params
  
  private
  
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render_unauthorized unless token
    
    begin
      decoded_token = JWT.decode(token, jwt_secret, true, algorithm: 'HS256')
      @current_user = User.find(decoded_token[0]['user_id'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render_unauthorized
    end
  end
  
  def current_user
    @current_user
  end
  
  def jwt_secret
    ENV['JWT_SECRET_KEY'] || 'default_secret_key'
  end
  
  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
  
  def set_pagination_params
    @page = params[:page]&.to_i || 1
    @per_page = params[:per_page]&.to_i || 20
  end
  
  def render_paginated_response(collection, serializer_class)
    paginated_collection = collection.page(@page).per(@per_page)
    
    render json: {
      data: paginated_collection.map { |item| serializer_class.new(item).as_json },
      meta: {
        current_page: paginated_collection.current_page,
        total_pages: paginated_collection.total_pages,
        total_count: paginated_collection.total_count,
        per_page: @per_page
      }
    }
  end
end

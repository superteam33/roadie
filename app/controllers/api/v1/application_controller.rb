class Api::V1::ApplicationController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pagination_params
  before_action :decode_uuid_params
  after_action :encode_response_ids
  
  private
  
  def authenticate_user!
    auth_header = request.headers['Authorization']
    return render_unauthorized unless auth_header
    
    # Extract token from "Bearer <token>" format
    token = auth_header.split(' ').last
    return render_unauthorized unless token
    
    begin
      # Find active session by access token
      session = UserSession.valid.find_by(access_token: token)
      return render_unauthorized unless session
      
      @current_user = session.user
    rescue ActiveRecord::RecordNotFound
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

  def decode_uuid_params
    # Decode UUIDs in URL parameters (like :id, :project_id, etc.)
    params.each do |key, value|
      if (key.end_with?('_id') || key == 'id') && value.present? && looks_like_encoded_id?(value)
        params[key] = decode_id(value)
      end
    end

    # Decode UUIDs in request body
    if request.post? || request.put? || request.patch?
      decode_request_body
    end
  end

  def encode_response_ids
    return unless response.body.present? && response.content_type&.include?('application/json')
    
    begin
      json_data = JSON.parse(response.body)
      encoded_data = encode_ids_in_json(json_data)
      response.body = encoded_data.to_json
    rescue JSON::ParserError
      # If JSON parsing fails, leave response as is
    end
  end

  # UUID Helper Methods
  def encode_id(id)
    return nil if id.nil?
    Base64.urlsafe_encode64(id.to_s, padding: false)
  end

  def decode_id(encoded_id)
    return nil if encoded_id.nil? || encoded_id.empty?
    
    begin
      decoded = Base64.urlsafe_decode64(encoded_id + padding_for_base64(encoded_id))
      decoded.to_i
    rescue ArgumentError, StandardError => e
      Rails.logger.error "Failed to decode ID: #{encoded_id}, Error: #{e.message}"
      nil
    end
  end

  def looks_like_encoded_id?(string)
    return false if string.nil? || string.empty?
    # Check if it looks like base64 (contains A-Z, a-z, 0-9, +, /, =, -)
    string.match?(/\A[A-Za-z0-9+\/=-]+\z/) && string.length > 1
  end

  def padding_for_base64(string)
    case string.length % 4
    when 2 then '=='
    when 3 then '='
    else ''
    end
  end

  private

  def decode_request_body
    return unless request.content_type&.include?('application/json')
    
    body = request.body.read
    request.body.rewind
    
    if body.present?
      begin
        json_data = JSON.parse(body)
        decoded_data = decode_ids_in_json(json_data)
        # Update the request parameters directly instead of modifying the body
        params.merge!(decoded_data) if decoded_data.is_a?(Hash)
      rescue JSON::ParserError
        # If JSON parsing fails, leave body as is
      end
    end
  end

  def decode_ids_in_json(obj)
    case obj
    when Hash
      decoded_hash = {}
      obj.each do |key, value|
        if key.end_with?('_uuid') || key == 'uuid'
          # Convert uuid field to id field
          id_key = key.gsub('_uuid', '_id').gsub('uuid', 'id')
          decoded_hash[id_key] = decode_id(value)
        else
          decoded_hash[key] = decode_ids_in_json(value)
        end
      end
      decoded_hash
    when Array
      obj.map { |item| decode_ids_in_json(item) }
    else
      obj
    end
  end

  def encode_ids_in_json(obj)
    case obj
    when Hash
      encoded_hash = {}
      obj.each do |key, value|
        if key == 'id' || key.end_with?('_id')
          # Convert id field to uuid field
          uuid_key = key.gsub('_id', '_uuid').gsub('id', 'uuid')
          encoded_hash[uuid_key] = encode_id(value)
        else
          encoded_hash[key] = encode_ids_in_json(value)
        end
      end
      encoded_hash
    when Array
      obj.map { |item| encode_ids_in_json(item) }
    else
      obj
    end
  end
end

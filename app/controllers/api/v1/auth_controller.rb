class Api::V1::AuthController < Api::V1::ApplicationController
  # Skip authentication for auth endpoints
  skip_before_action :authenticate_user!, only: [:signup, :login]
  # Skip UUID middleware for auth endpoints since they don't use UUIDs
  skip_before_action :decode_uuid_params, only: [:signup, :login]
  skip_after_action :encode_response_ids, only: [:signup, :login]
  
  
  # POST /api/v1/auth/signup
  def signup
    begin
      # Get auth parameters
      auth_params = params[:auth] || params
      
      # Decrypt the password
      decrypted_password = decrypt_password(auth_params[:encrypted_password])
      return unless decrypted_password
      
      # Create user with decrypted password
      user = User.new(
        first_name: auth_params[:first_name],
        last_name: auth_params[:last_name],
        email: auth_params[:email],
        role: auth_params[:role],
        password: decrypted_password,
        password_confirmation: decrypted_password
      )
      
      if user.save
        # Create session
        session = user.create_session!
        
        render json: {
          message: "User created successfully",
          user: UserSerializer.new(user).as_json,
          access_token: session.access_token,
          expires_at: session.expires_at
        }, status: :created
      else
        render json: {
          error: "Failed to create user",
          details: user.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Signup error: #{e.message}"
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end
  
  # POST /api/v1/auth/login
  def login
    begin
      # Get auth parameters
      auth_params = params[:auth] || params
      
      # Decrypt the password
      decrypted_password = decrypt_password(auth_params[:encrypted_password])
      return unless decrypted_password
      
      # Find user by email
      user = User.find_by(email: auth_params[:email])
      
      if user && user.authenticate(decrypted_password)
        # Create new session
        session = user.create_session!
        
        render json: {
          message: "Login successful",
          user: UserSerializer.new(user).as_json,
          access_token: session.access_token,
          expires_at: session.expires_at
        }
      else
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "Login error: #{e.message}"
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end
  
  # POST /api/v1/auth/logout
  def logout
    begin
      current_user.logout!
      render json: { message: "Logged out successfully" }
    rescue => e
      Rails.logger.error "Logout error: #{e.message}"
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/auth/me
  def me
    render json: {
      user: UserSerializer.new(current_user).as_json,
      session: {
        access_token: current_user.active_session&.access_token,
        expires_at: current_user.active_session&.expires_at
      }
    }
  end
  
  private
  
  def decrypt_password(encrypted_password)
    private_key = RsaService.get_private_key
    unless private_key
      render json: { error: "Server configuration error" }, status: :service_unavailable
      return nil
    end
    
    Rails.logger.info "Attempting to decrypt password. Length: #{encrypted_password.length}"
    Rails.logger.info "Encrypted data preview: #{encrypted_password[0..50]}..."
    
    decrypted = RsaService.decrypt(encrypted_password, private_key)
    unless decrypted
      Rails.logger.error "Failed to decrypt password with any padding method"
      render json: { error: "Failed to decrypt password" }, status: :bad_request
      return nil
    end
    
    Rails.logger.info "Password decrypted successfully: #{decrypted}"
    decrypted
  end
end

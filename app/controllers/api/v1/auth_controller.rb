class Api::V1::AuthController < ApplicationController
  def login
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      token = generate_jwt_token(user)
      render json: {
        user: UserSerializer.new(user).as_json,
        token: token
      }
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
  
  def register
    user = User.new(user_params)
    
    if user.save
      token = generate_jwt_token(user)
      render json: {
        user: UserSerializer.new(user).as_json,
        token: token
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def me
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token
      begin
        decoded_token = JWT.decode(token, jwt_secret, true, algorithm: 'HS256')
        user = User.find(decoded_token[0]['user_id'])
        render json: { user: UserSerializer.new(user).as_json }
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        render json: { error: 'Invalid token' }, status: :unauthorized
      end
    else
      render json: { error: 'No token provided' }, status: :unauthorized
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end
  
  def generate_jwt_token(user)
    payload = {
      user_id: user.id,
      email: user.email,
      exp: 24.hours.from_now.to_i
    }
    
    JWT.encode(payload, jwt_secret, 'HS256')
  end
  
  def jwt_secret
    ENV['JWT_SECRET_KEY'] || 'default_secret_key'
  end
end

class RsaService
  class << self
    def generate_key_pair
      # Generate a new RSA key pair
      private_key = OpenSSL::PKey::RSA.new(2048)
      public_key = private_key.public_key
      
      {
        private_key: private_key.to_pem,
        public_key: public_key.to_pem
      }
    end
    
    def encrypt(plaintext, public_key_pem)
      public_key = OpenSSL::PKey::RSA.new(public_key_pem)
      encrypted = public_key.public_encrypt(plaintext, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
      Base64.encode64(encrypted)
    end
    
    def decrypt(encrypted_data, private_key_pem)
      private_key = OpenSSL::PKey::RSA.new(private_key_pem)
      decoded_data = Base64.decode64(encrypted_data)
      
      # Try different padding methods in order of preference
      padding_methods = [
        OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING,
        OpenSSL::PKey::RSA::PKCS1_PADDING,
        nil  # Default padding
      ]
      
      padding_methods.each do |padding|
        begin
          if padding
            result = private_key.private_decrypt(decoded_data, padding)
          else
            result = private_key.private_decrypt(decoded_data)
          end
          Rails.logger.info "RSA decryption successful with padding: #{padding || 'default'}"
          return result
        rescue => e
          Rails.logger.debug "RSA decryption failed with padding #{padding || 'default'}: #{e.message}"
          next
        end
      end
      
      Rails.logger.error "RSA decryption failed with all padding methods"
      nil
    rescue => e
      Rails.logger.error "RSA decryption failed: #{e.message}"
      nil
    end
    
    def get_public_key
      # Get the public key from environment or generate a new one
      if ENV['RSA_PUBLIC_KEY'].present?
        ENV['RSA_PUBLIC_KEY']
      else
        # Generate a new key pair and store it
        key_pair = generate_key_pair
        # In production, you should store these securely
        Rails.logger.warn "RSA keys not configured. Using generated keys for this session only."
        key_pair[:public_key]
      end
    end
    
    def get_private_key
      # Get the private key from environment
      if ENV['RSA_PRIVATE_KEY'].present?
        ENV['RSA_PRIVATE_KEY']
      else
        Rails.logger.error "RSA private key not configured"
        nil
      end
    end
  end
end

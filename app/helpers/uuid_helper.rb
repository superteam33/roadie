class UuidHelper
  class << self
    # Simple base64 encoding of ID
    def encode_id(id)
      return nil if id.nil?
      Base64.urlsafe_encode64(id.to_s, padding: false)
    end

    # Simple base64 decoding to ID
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

    # Check if string looks like encoded ID
    def looks_like_encoded_id?(string)
      return false if string.nil? || string.empty?
      string.match?(/\A[A-Za-z0-9_-]+\z/) && string.length > 1
    end

    private

    def padding_for_base64(string)
      case string.length % 4
      when 2 then '=='
      when 3 then '='
      else ''
      end
    end
  end
end

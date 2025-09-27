module UuidEncodable
  extend ActiveSupport::Concern

  included do
    # Add class methods
    def self.find_by_uuid(uuid)
      id = UuidHelper.decode_id(uuid)
      find_by(id: id) if id
    end

    def self.find_by_uuid!(uuid)
      id = UuidHelper.decode_id(uuid)
      find(id) if id
    end
  end

  # Instance methods
  def uuid
    UuidHelper.encode_id(id)
  end

  def to_param
    uuid
  end
end

class Identity
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :cloud_user, class_name: CloudUser.name
  field :provider, type: String
  field :uid, type: String
  field :_id, type: String, default: ->{ Identity.id_for(provider, uid) }

  def self.for(provider, uid, created_at=nil)
    new(:provider => provider, :uid => uid) do |i|
      i.created_at = created_at if created_at
    end
  end
  def self.id_for(provider, uid)
    "#{provider.to_s.gsub(/([\/\:])/, '\\\1')}:#{uid.to_s.gsub(/([\/\:])/, '\\\1')}"
  end
end

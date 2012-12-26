class RestIdentity < OpenShift::Model
  attr_accessor :provider, :uid, :active, :created_at, :updated_at

  def initialize(identity, url, nolinks=false)
    self.provider = identity.provider
    self.uid = identity.uid
    self.active = identity.active
    self.created_at = identity.created_at
    self.updated_at = identity.updated_at
  end

  def to_xml(options={})
    options[:tag_name] = "identity"
    super(options)
  end
end

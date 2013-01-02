class RestIdentity < OpenShift::Model
  attr_accessor :provider, :uid, :created_at, :updated_at, :scopes

  def initialize(identity, url, nolinks=false)
    self.provider = identity.provider
    self.uid = identity.uid
    self.created_at = identity.created_at
    self.updated_at = identity.updated_at
    self.scopes = Array(identity.scopes)
  end

  def to_xml(options={})
    options[:tag_name] = "identity"
    super(options)
  end
end

class RestAuthorization < OpenShift::Model
  attr_accessor :token, :scopes, :client, :note, :created_at, :expires_in, :expires_in_seconds, :refresh_token

  def initialize(auth, url, nolinks=false)
    [:token, :refresh_token, :created_at, :expires_in, :expires_in_seconds, :note].each{ |sym| self.send("#{sym}=", auth.send(sym)) }
    self.client = { :id => auth.application.uid, :name => auth.application.name } if auth.application.uid != 'default'
    self.scopes = auth.scopes.to_s
  end

  def to_xml(options={})
    options[:tag_name] = "authorization"
    super(options)
  end
end

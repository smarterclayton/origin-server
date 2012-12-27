class RestAuthorization < OpenShift::Model
  attr_accessor :token, :client, :note, :created_at, :expires_in, :expires_in_seconds

  def initialize(auth, url, nolinks=false)
    [:token, :token, :created_at, :expires_in, :expires_in_seconds, :note].each{ |sym| self.send("#{sym}=", auth.send(sym)) }
    self.client = { :id => auth.application.uid, :name => auth.application.name } if auth.application.uid != 'default'
  end

  def to_xml(options={})
    options[:tag_name] = "authorization"
    super(options)
  end
end

class RestAuthorization < OpenShift::Model
  attr_accessor :token, :application, :note, :created_at, :expires_in, :expires_at

  def initialize(auth, url, nolinks=false)
    [:token, :token, :created_at, :expires_in].each{ |sym| self.send("#{sym}=", auth.send(sym)) }
    self.application = { :id => auth.application.uid, :name => auth.application.name }
    self.expires_at = created_at + expires_in.seconds
  end

  def to_xml(options={})
    options[:tag_name] = "authorization"
    super(options)
  end
end

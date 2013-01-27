class RestAuthorization < OpenShift::Model
  attr_accessor :id, :token, :note, :created_at, :expires_in, :expires_in_seconds

  def initialize(auth, url, nolinks=false)
    [:token, :created_at, :expires_in, :expires_in_seconds, :note].each{ |sym| self.send("#{sym}=", auth.send(sym)) }
    self.id = auth._id
  end

  def to_xml(options={})
    options[:tag_name] = "authorization"
    super(options)
  end
end

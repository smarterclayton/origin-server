class RestMember < OpenShift::Model
  attr_accessor :id, :type, :name, :role, :from, :owner
  
  def initialize(member, default_role, owner, url, nolinks=false)
    type = case member._type
           when 'team' then 'team'
           else
            'user'
           end
    self.name = member.name || "#{type}:#{member.id}"
    self.id = member._id
    #self.type = type
    self.role = member.role || default_role
    self.from = Array(member.from) if member.from
    self.owner = owner
=begin
    self.links = {
      "GET" => Link.new("Get SSH key", "GET", URI::join(url, "user/keys/#{name}")),
      "UPDATE" => Link.new("Update SSH key", "PUT", URI::join(url, "user/keys/#{name}"), [
        Param.new("type", "string", "Type of Key", SshKey::VALID_SSH_KEY_TYPES),
        Param.new("content", "string", "The key portion of an rsa key (excluding ssh key type and comment)"),
      ]),
      "DELETE" => Link.new("Delete SSH key", "DELETE", URI::join(url, "user/keys/#{name}"))
    } unless nolinks
=end
  end
  
  def to_xml(options={})
    options[:tag_name] = "member"
    super(options)
  end
end
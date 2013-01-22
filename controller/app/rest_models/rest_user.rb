class RestUser < OpenShift::Model
  attr_accessor :login, :consumed_gears, :capabilities, :plan_id, :usage_account_id, :links, :consumed_gear_sizes, :max_gears, :identities, :current_identity, :created_at

  def initialize(cloud_user, url, nolinks=false)
    consumed_map = {}
    cloud_user.domains.each do |domain|
      domain.applications.each do |a|
        a.group_instances.each do |ginst|
          size = ginst.gear_size
          consumed_map[size] = 0 if not consumed_map.has_key?(size)
          consumed_map[size] = consumed_map[size] + ginst.gears.size
        end
      end
    end if cloud_user.consumed_gears > 0

    if identity = cloud_user.current_identity
      self.login = identity.id
      self.current_identity = RestIdentity.new(identity, url, true)
    end

    self.consumed_gears = cloud_user.consumed_gears
    self.capabilities = cloud_user.get_capabilities
    self.max_gears = capabilities["max_gears"]
    self.capabilities.delete("max_gears")
    self.plan_id = cloud_user.plan_id
    self.usage_account_id = cloud_user.usage_account_id
    self.consumed_gear_sizes = consumed_map
    self.identities = cloud_user.identities.map{ |i| RestIdentity.new(i, url, false) }
    self.created_at = cloud_user.updated_at

    unless nolinks
      @links = {
        "LIST_KEYS" => Link.new("Get SSH keys", "GET", URI::join(url, "user/keys")),
        "ADD_KEY" => Link.new("Add new SSH key", "POST", URI::join(url, "user/keys"), [
          Param.new("name", "string", "Name of the key"),
          Param.new("type", "string", "Type of Key", SshKey.get_valid_ssh_key_types()),
          Param.new("content", "string", "The key portion of an rsa key (excluding ssh-rsa and comment)"),
        ]),
        #"ADD_AUTHORIZATION" => Link.new("Create new authorization", "POST", URI::join(url, "user/authorizations"), nil, [
        #  OptionalParam.new("note", "string", "A description of this authorization", nil, nil),
        #  OptionalParam.new("expires_in", "integer", "The number of seconds this authorization will last", nil, 7200),
        #  OptionalParam.new("scopes", "string", "A space delimited list of valid scopes the token will grant", Doorkeeper.configuration.scopes.to_a + Doorkeeper.configuration.parameterized_scopes, Doorkeeper.configuration.default_scopes.to_s),
        #  OptionalParam.new("client_id", "string", "The identifier of a client program that this token will be limited to.", nil, nil),
        #]),
        #"LIST_AUTHORIZATIONS" => Link.new("List authorizations", "GET", URI::join(url, "user/authorizations")),
      }
      @links["DELETE_USER"] = Link.new("Delete user. Only applicable for subaccount users.", "DELETE", URI::join(url, "user"), nil, [
        OptionalParam.new("force", "boolean", "Force delete user. i.e. delete any domains and applications under this user", [true, false], false)
      ]) if cloud_user.parent_user_id
    end
  end
  
  def to_xml(options={})
    options[:tag_name] = "user"
    super(options)
  end
end

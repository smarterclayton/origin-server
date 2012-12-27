require 'doorkeeper/config'
class Doorkeeper::Config
  option :max_access_token_expires_in, :default => 1.month.seconds
end

Doorkeeper.configure do
  orm :mongoid3

  default_scopes :userinfo
  optional_scopes :userinfo, :scale, :read, :control, :grant

  resource_owner_authenticator do
    Rails.logger.debug "Resource owner authenticator #{params.inspect}"
    current_user || authenticate_user!
  end

  resource_owner_from_credentials do |routes|
    Rails.logger.debug "Resource owner from credentials #{params[:username]}"
    auth = OpenShift::AuthService.instance.authenticate(request, params[:username], params[:password])
    CloudUser.with_identity(auth[:provider], auth[:username]).find_by if auth
  end
end


require 'doorkeeper/oauth/helpers/scope_checker'
module Doorkeeper::OAuth::Helpers::ScopeChecker
  def self.valid?(scope, server_scopes)
    scope.present? &&
    scope !~ /[\n|\r|\t]/ &&
    Doorkeeper::OAuth::Scopes.from_string(scope).all? do |s|
      server_scopes.exists?(s) || s.to_s =~ %r[(?:app|domain)/\w{1,20}/\w{1,10}]
    end
  end
end

require 'doorkeeper/models/access_token'
class Doorkeeper::AccessToken
  field :note, type: String
  validates_length_of :note, maximum: 1024, allow_blank: true
  attr_accessible :note
end

require 'doorkeeper/oauth/password_access_token_request'
class Doorkeeper::OAuth::PasswordAccessTokenRequest
  attr_accessor :note

  def initialize(server, client, resource_owner, parameters = {})
    @server          = server
    @resource_owner  = resource_owner
    @client          = client
    @original_scopes = parameters[:scope]
    @note            = parameters[:note]
  end

  private
    def create_access_token
      @access_token = Doorkeeper::AccessToken.create!({
        :application_id     => client.id,
        :resource_owner_id  => resource_owner.id,
        :scopes             => scopes.to_s,
        :note               => note,
        :expires_in         => server.access_token_expires_in,
        :use_refresh_token  => server.refresh_token_enabled?
      })
    end
end

=begin # Not needed if there is a direct auth path
require 'doorkeeper/oauth/client/credentials'
class Doorkeeper::OAuth::Client::Credentials
  def blank?
    false
  end
end
=end

ActiveSupport.on_load(:action_controller) do
  require 'o_auth_client'
  require 'doorkeeper/helpers/controller'
  module Doorkeeper::Helpers::Controller
    protected
      include UserActionLogger
      include AuthenticationHelper
  end
end

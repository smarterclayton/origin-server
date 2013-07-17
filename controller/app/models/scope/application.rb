class Scope::Application < Scope::Parameterized
  matches 'application/:id/:app_scope'
  description "Grant access to perform API actions against a single application."

  APP_SCOPES = {
    :build => nil,
    :scale => nil,
    :read => 'Grant read-only access to a single application.',
  }.freeze

  def allows_action?(controller)
    case app_scope
    when :scale then true #FIXME temporary
    when :build then true #FIXME temporary
    when :read then controller.request.method == "GET" && !controller.is_a?(AuthorizationsController)
    else false
    end
  end

  def authorize_action?(permission, resource, other_resources, user)
    case app_scope
    when :scale then resource === Application && :scale_cartridge == permission
    end
  end

  def limits_access(criteria)
    case criteria.klass
    when Application then (criteria.options[:for_ids] ||= []) << @id
    when Domain then (criteria.options[:for_ids] ||= []) << Application.only(:domain_id).find(@id).domain_id
    else criteria.options[:visible] ||= false
    end
    criteria
  end

  def self.describe
    APP_SCOPES.map{ |k,v| s = with_params(nil, k); [s, v, default_expiration(s), maximum_expiration(s)] unless v.nil? }.compact
  end

  private
    def id=(s)
      s = s.to_s
      raise Scope::Invalid, "id must be less than 40 characters" unless s.length < 40
      s = Moped::BSON::ObjectId.from_string(s)
      @id = s
    end

    def app_scope=(s)
      raise Scope::Invalid, "'#{s}' is not a valid application scope" unless APP_SCOPES.keys.any?{ |k| k.to_s == s }
      @app_scope = s.to_sym
    end
end

class Scope::Domain < Scope::Parameterized
  matches 'domain/:id/:domain_scope'
  description "Grant access to perform API actions against a single domain and the contained applications."

  DOMAIN_SCOPES = {
    :read => 'Grant read-only access to a single domain.',
    :manage => 'Allow managing the domain.',
  }.freeze

  def allows_action?(controller)
    case domain_scope
    when :read then controller.request.method == "GET"
    else true
    end
  end

  def authorize_action?(permission, resource, other_resources, user)
    case domain_scope
    when :manage then Domain === resource || Application === resource
    end
  end

  def limits_access(criteria)
    case criteria.klass
    when Application then criteria = criteria.where(:domain_id => @id)
    when Domain then (criteria.options[:for_ids] ||= []) << @id
    else criteria.options[:visible] ||= false
    end
    criteria
  end

  def self.describe
    DOMAIN_SCOPES.map{ |k,v| s = with_params(nil, k); [s, v, default_expiration(s), maximum_expiration(s)] unless v.nil? }.compact
  end

  private
    def id=(s)
      s = s.to_s
      raise Scope::Invalid, "id must be less than 40 characters" unless s.length < 40
      s = Moped::BSON::ObjectId.from_string(s)
      @id = s
    end

    def domain_scope=(s)
      raise Scope::Invalid, "'#{s}' is not a valid domain scope" unless DOMAIN_SCOPES.keys.any?{ |k| k.to_s == s }
      @domain_scope = s.to_sym
    end
end

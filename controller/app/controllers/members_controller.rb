class MembersController < BaseController

  def index
    members.map{ |m| get_rest_member(m) }
    render_success(:ok, "members", members, "Found #{members.length} members.")
  end

  def create
    errors = []
    new_members = []
    (Array(params[:members]) || Array(params[:member]) || []).each do |m| 
      if m.is_a? Hash
        id, role = m.values_at(:id, :role)
        unless id
          errors << 'You must provide a valid id for your member.'
          next
        end
        unless role = Role.for(role)
          errors << "Role '#{m[:role]}' must be one of : #{Role.all.join(', ')}"
          next
        end
        new_members << Member.new{ |m| m._id = id; m.role = role }
        next
      end
      errors << "You must provide a member with an id and role."
    end.blank? or errors << "You must provide at least a single role."

    return render_error(:unprocessable_entity, errors.first) if errors.length == 1
    return render_error(:unprocessable_entity, "The members could not be added due to validation errors.", nil, nil, nil, errors) if errors.length > 1
  end

  protected
    def membership
      raise "Must be implemented to return the resource under access control"
    end

    def get_rest_member(m)
      RestMember.new(m, membership.default_role, is_owner?(m), get_url, nolinks)
    end

    def is_owner?(member)
      membership.owner_id == member._id
    end

    def members
      membership.members
    end
end
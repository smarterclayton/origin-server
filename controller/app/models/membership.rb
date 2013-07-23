#
# A model with the ability to add and remove membership.  Membership changes may require
# work to be done on distributed resources associated with this model, or on child resources.
#
module Membership
  extend ActiveSupport::Concern
  extend AccessControlled

  def has_member?(o)
    members.include?(o)
  end

  def role_for(member_or_id)
    id = member_or_id.respond_to?(:_id) ? member_or_id._id : member_or_id
    members.inject(default_role){ |r, m| return (m.role || r) if m._id == id; r }
    nil
  end

  def default_role
    :read
  end

  def member_ids
    members.map(&:_id)
  end

  def add_members(*args)
    from = args.pop if args.last.is_a? Symbol
    changing_members do
      args.flatten(1).map do |arg|
        m = self.class.to_member(arg)
        m.from = [from.to_s] if from
        if exists = members.find(m._id) rescue nil
          exists.merge(m)
        else
          members.push(m)
        end
      end
    end
    self
  end

  def remove_members(*args)
    from = args.pop if args.last.is_a? Symbol
    return self if args.empty?
    changing_members do
      Array(members.find(*args)).each{ |m| m.delete if m.remove(from ? from.to_s : nil) }
    end
    self
  end

  # FIXME
  # Mongoid has no support for adding/removing embedded relations in bulk in 3.0.
  # Until that is available, provide a block form that signals that the set of operations
  # is intended to be deferred until a save on the document is called, and track
  # the ids that are removed and added
  #
  # FIXME
  # does not handle _id collisions across types.  May or may not want to resolve.
  # 
  def changing_members(&block)
    _assigning do
      ids = member_ids
      instance_eval &block
      new_ids = member_ids

      added, removed = (new_ids - ids), (ids - new_ids)

      @original_members ||= ids
      @members_added ||= []; @members_removed ||= []
      @members_added -= removed; @members_removed -= added
      @members_added.concat(added).uniq!; @members_removed.concat(removed & @original_members).uniq!
    end
    self
  end

  def has_member_changes?
    @members_added.present? || @members_removed.present? || members.any?(&:role_changed?)
  end

  protected
    def parent_membership_relation
      relations.values.find{ |r| r.macro == :belongs_to }
    end

    def default_members
      if parent = parent_membership_relation
        p = send(parent.name)
        p.inherit_membership.each{ |m| m.from = [parent.name.to_s] } if p
      end || []
    end

    #
    # The list of member ids that changed on the object.  The change_members op
    # is best if it is consistent on all access controlled classes
    #
    def members_changed(added, removed, changed_roles)
      queue_op(:change_members, added: added.presence, removed: removed.presence, changed: changed_roles.presence)
    end

    # FIXME create a standard pending operations model mixin that uniformly handles queueing on all type
    def queue_op(op, args)
      (relations['pending_ops'] ? pending_ops : pending_op_groups).build(:op_type => op, :state => :init, :args => args.stringify_keys)
    end

    def handle_member_changes
      if persisted?
        changing_members{ members.concat(default_members) } if members.empty?
        if has_member_changes?
          changed_roles = members.select{ |m| m.role_changed? && !(@members_added && @members_added.include?(m._id)) }.map{ |m| [m._id].concat(m.role_change) }
          members_changed(@members_added, @members_removed, changed_roles)
          @original_members, @members_added, @members_removed = nil
        end
      else
        members.concat(default_members)
      end
      @_children = nil # ensure the child collection is recalculated
      true
    end

  module ClassMethods
    def has_members(opts=nil)
      embeds_many :members, as: :access_controlled, cascade_callbacks: true
      before_save :handle_member_changes

      index({'members._id' => 1}, {:sparse => true})

      if opts and through = opts[:through].to_s.presence
        define_method :parent_membership_relation do
          relations[through]
        end
      end
      if opts and role = opts[:default_role]
        define_method :default_role do
          role
        end
      end
    end

    #
    # Overrides AccessControlled#accessible
    #
    def accessible(to)
      criteria = where(:'members._id' => to.is_a?(String) ? to : to._id)
      if to.respond_to?(:scopes) && (scopes = to.scopes)
        criteria = scopes.limit_access(criteria)
      end
      criteria
    end    

    def to_member(arg)
      if Member === arg 
        arg
      else
        if arg.respond_to?(:as_member) 
          arg.as_member 
        else
          Member.new{ |mem| mem._id = arg }
        end
      end
    end
  end
end
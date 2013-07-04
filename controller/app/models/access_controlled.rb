#
# A model with the ability to add and remove membership.  Membership changes may require
# work to be done on distributed resources associated with this model, or on child resources.
#
module AccessControlled
  extend ActiveSupport::Concern

  def has_member?(o)
    members.include?(o)
  end

  def member_ids
    members.map(&:_id)
  end

  def add_members(*args)
    from = args.pop if args.last.is_a? Symbol
    changing_members do
      args.flatten(1).map do |arg|
        m = self.class.to_member(arg)
        m.from = from
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
      Array(members.find(*args)).each do |o|
        if from.nil?
          # remove members that are directly granted access 
          if o.from.nil?
            o.delete
          elsif o.explicit_grant?
            o.explicit_grant = false
          end
        elsif o.from == from.to_s
          # clear the source of the membership if the member has a direct grant
          # otherwise remove the member
          if o.explicit_grant?
            o.from = nil
            o.explicit_grant = nil
          else
            o.delete
          end
        end
      end
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
      @members_added.concat(added); @members_removed.concat(removed & @original_members)
    end
    self
  end

  def has_member_changes?
    @members_added.present? || @members_removed.present?
  end

  protected
    def default_members
      if parent = relations.values.find{ |r| r.macro == :belongs_to }
        p = send(parent.name)
        p.inherit_membership.each{ |m| m.from = parent.name } if p
      end || []
    end

    #
    # The list of member ids that changed on the object.  The change_members op
    # is best if it is consistent on all access controlled classes
    #
    def members_changed(added, removed)
      queue_op(:change_members, added: added.presence, removed: removed.presence)
    end

    # FIXME create a standard pending operations model mixin that uniformly handles queueing on all type
    def queue_op(op, args)
      (relations['pending_ops'] ? pending_ops : pending_op_groups).build(:op_type => op, :state => :init, :args => args.stringify_keys)
    end

    def handle_member_changes
      if persisted?
        changing_members{ members.concat(default_members) } if members.empty?
        if @members_added.present? || @members_removed.present?
          members_changed(@members_added.uniq, @members_removed.uniq)
          @original_members, @members_added, @members_removed = nil
        end
      else
        members.concat(default_members)
      end
      @_children = nil # ensure the child collection is recalculated
      true
    end

  module ClassMethods
    def has_members
      embeds_many :members, as: :access_controlled, cascade_callbacks: true
      before_save :handle_member_changes

      index({'members._id' => 1}, {:sparse => true})
    end

    def accessible(to)
      # FIXME simple implementation, does not take into teams or bulk ownership.
      where(:'members._id' => to.is_a?(String) ? to : to._id)
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
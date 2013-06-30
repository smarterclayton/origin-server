#
# A model with the ability to add and remove membership.  Membership changes may require
# work to be done on distributed resources associated with this model, or on child resources.
#
module AccessControlled
  extend ActiveSupport::Concern

  def member_of?(o)
    members.include?(o)
  end

  def member_ids
    members.map(&:_id)
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

      @members_added ||= []; @members_removed ||= []
      @members_added -= removed; @members_removed -= added
      @members_added.concat(added); @members_removed.concat(removed)
    end
    self
  end

  def has_member_changes?
    @members_added.present? || @members_removed.present?
  end

  protected
    def default_members
      if parent = relations.values.find{ |r| r.macro == :belongs_to }
        send(parent.name).inherit_membership.each{ |m| m.from = parent.name }
      else
        []
      end
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
      (relations['pending_ops'] ? pending_ops : pending_op_groups).build(:op_type => op, :state => :init, :args => args)
    end

    def handle_member_changes
      if persisted?
        _assigning do
          changing_members{ members.concat(default_members) } if members.empty?
          if @members_added.present? || @members_removed.present?
            members_changed(@members_added.uniq, @members_removed.uniq)
            @members_added, @members_removed = nil
          end
        end
      else
        members.concat(default_members)
      end
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
  end
end
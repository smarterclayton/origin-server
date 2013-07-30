class Member
  include Mongoid::Document
  embedded_in :access_controlled, polymorphic: true

  field :_id, :as => :_id, type: Moped::BSON::ObjectId, default: -> { nil }
  field :_type, :as => :t, type: String, default: ->{ self.class.name if hereditary? }
  field :name,  :as => :n, type: String
  field :from,  :as => :f, type: Array
  field :role,  :as => :r, type: Symbol
  field :explicit_grant, :as => :e, type: Symbol
  attr_accessible :_id, :role

  validates_presence_of :_id, :message => 'You must provide a valid id for your member.'
  validates_presence_of :role, :message => "must be one of : #{Role.all.join(', ')}"

  def ==(other)
    _id == other._id && (member_type === other || self.class == other.class)
  end

  def merge(other)
    if other.from.blank?
      if from.present?
        self.explicit_grant = other.role
        self.role = Role.higher_of(other.role, role)
      else
        self.explicit_grant = nil
        self.role = other.role
      end
    else
      self.explicit_grant = role if from.blank?      
      self.role = Role.higher_of(other.role, role)
      ((self.from ||= []).concat(Array(other.from))).uniq!
    end
    self
  end

  #
  # Remove the specific source of the membership - will
  # return true if the member should be removed because
  # there is no longer an explicit grant or source.
  #
  def remove(source)
    if source.nil?
      if from.blank?
        # member only explicitly
        true
      elsif explicit_grant?
        # FIXME: member still via an implicit role, need to recalculate
        self.role = Role.higher_of(explicit_grant, role)
        self.explicit_grant = nil
        false
      end
    else
      from.delete(source) if from
      if explicit_grant?
        if from.blank?
          # member still via an explicit grant
          self.role = explicit_grant
          self.explicit_grant = nil
        else
          # recalculate role based on explicit grant
          raise "Need to recalculate roles based on remaining grants"
        end
        false
      else
        # member only if other implict grants present
        from.blank?
      end
    end
  end

  def member_type
    CloudUser
  end

  def _type=(obj)
    super obj == 'user' ? nil : obj
  end
end
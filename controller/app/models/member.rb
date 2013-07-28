class Member
  include Mongoid::Document
  embedded_in :access_controlled, polymorphic: true

  field :name,  :as => :n, type: String
  field :_type, :as => :t, type: String, default: ->{ self.class.name if hereditary? }
  field :from,  :as => :f, type: Array
  field :role,  :as => :r, type: Symbol
  field :explicit_grant, :as => :e, type: Boolean
  attr_accessible :_id, :role

  def ==(other)
    _id == other._id && (member_type === other || self.class == other.class)
  end

  def merge(other)
    self.explicit_grant = true if from != other.from
    ((self.from ||= []).concat(other.from)).uniq! if from.nil?
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
        true
      elsif explicit_grant?
        self.explicit_grant = nil
        false
      end
    else
      from.delete(source) if from
      if explicit_grant?
        self.explicit_grant = nil
        false
      else
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
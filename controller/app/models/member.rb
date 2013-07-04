class Member
  include Mongoid::Document
  embedded_in :access_controlled, polymorphic: true

  #before_create ->{ access_controlled.members_changed([_id], nil); puts "member created #{atomic_updates.inspect}" }
  #before_destroy ->{ access_controlled.members_changed(nil, [_id]); puts "member delete #{atomic_updates.inspect}" }

  field :_type, :as => :t, type: String, default: ->{ self.class.name if hereditary? }
  field :from,  :as => :f, type: String
  field :role,  :as => :r, type: Symbol
  field :explicit_grant, :as => :e, type: Boolean
  attr_accessible :_id

  def ==(other)
    _id == other._id && (member_type === other || self.class == other.class)
  end

  def merge(other)
    self.explicit_grant = true if from != other.from
    self.from = other.from if from.nil?
  end

  def member_type
    CloudUser
  end

  def from=(obj)
    super obj
  end

  def _type=(obj)
    super obj == 'user' ? nil : obj
  end
end
class Member
  include Mongoid::Document
  embedded_in :access_controlled, polymorphic: true

  field :_type, :as => :t, type: String, default: ->{ self.class.name if hereditary? }
  field :from,  :as => :f, type: String
  field :role,  :as => :r, type: String
  attr_accessible :_id

  def ==(other)
    _id == other._id && member_type === other
  end

  def member_type
    nil
  end

  def from=(obj)
    super obj
  end

  def _type=(obj)
    super obj == 'user' ? nil : obj
  end
end
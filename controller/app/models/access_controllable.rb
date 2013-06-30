module AccessControllable
  extend ActiveSupport::Concern

  def as_member
    Member.new do |u|
      u._id = self._id
      u._type = self.class.member_type
    end
  end

  module ClassMethods
    def member_as(s)
      @member_as = (s == :user) ? nil : s.to_s
    end

    def member_type
      @member_as
    end

    def members_of(acl)
      self.in(
        _id:
          if AccessControlled === acl
            acl.members.inject([]) do |a, m|
              a << m._id if @member_as == m._type
              a
            end
          else
            acl
          end
      )
    end
  end
end
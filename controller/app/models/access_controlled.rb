#
# A model with the ability to add and remove membership.  Membership changes may require
# work to be done on distributed resources associated with this model, or on child resources.
#
module AccessControlled
  extend ActiveSupport::Concern

  module ClassMethods
    def accessible(to)
      criteria = queryable
      if to.respond_to?(:scopes) && (scopes = to.scopes)
        criteria = scopes.limit_access(criteria)
      end
      criteria
    end
  end
end
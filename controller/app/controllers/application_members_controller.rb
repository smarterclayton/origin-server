class ApplicationMembersController < MembersController
  protected
    def membership
      @membership ||= get_application
    end
end
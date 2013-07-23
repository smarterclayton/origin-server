module Role
  def self.valid?(sym)
    ROLES.include?(sym)
  end

  def self.in?(given, has)
    if i = ROLES.index(has)
      given && i >= ROLES.index(given)
    end
  end

  def self.allows_application_ssh?(given)
    in?(:edit, given)
  end

  private
    ROLES = [:read, :control, :edit, :manage]
end
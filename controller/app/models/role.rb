module Role
  def self.for(value)
    ROLES.any?{ |s| s.to_s == value.to_s }
  end

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

  def self.all
    ROLES
  end

  private
    ROLES = [:read, :control, :edit, :manage].freeze
end
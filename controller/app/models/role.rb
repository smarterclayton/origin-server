module Role
  def self.for(value)
    ROLES.detect{ |s| s.to_s == value.to_s }
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

  def self.higher_of(a, b)
    a = ROLES.index(a)
    b = ROLES.index(b)
    ROLES[[a || b, b || a].max]
  end

  def self.all
    ROLES
  end

  private
    ROLES = [:read, :control, :edit, :manage].freeze
end
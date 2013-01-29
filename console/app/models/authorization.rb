#
# The REST API model object representing a user authorization
#
class Authorization < RestApi::Base
  schema do
    string :token, :note, :identity
    integer :expires_in, :expires_in_seconds
    datetime :created_at
  end

  belongs_to :user

  def created_at
    DateTime.parse(attributes[:created_at]) rescue nil
  end

  def expired?
    not (expires_in_seconds > 0)
  end
  def expired_time
    created_at + expires_in.seconds
  end

  def scopes
    (attributes[:scopes] || (attributes[:scope] || '').split(',')).map(&:to_sym)
  end
  def scopes=(a)
    self.scope = a
  end
  def scope=(scopes)
    attributes.delete :scopes
    attributes[:scope] = Array(scopes).join(',')
  end

  def reuse!
    attributes[:reuse] = true
  end

  def to_headers
    {'Authorization' => "Bearer #{token}"}
  end
end

class OAuthClient
  include Mongoid::Document
  include Mongoid::Timestamps

  doorkeeper_client!

  def self.default_client
    o = {
      :name => 'Default OAuth Client',
      :uid => 'default',
      :secret => 'none',
      :redirect_uri => 'https://localhost/no/authorize'
    }
    @default_client = where(o).first || create!(o, without_protection: true)
  end
  skip_callback :create, :before, :generate_credentials, :if => lambda { self.uid == 'default' }

  field :name, :type => String
  field :uid, :type => String
  field :secret, :type => String
  field :redirect_uri, :type => String

  index({:uid => 1}, {:unique => true})

  attr_accessible :name, :redirect_uri

  def self.find_for_oauth_authentication(uid)
    uid.present? ? where(:uid => uid).first : default_client
  end

  def self.oauth_authenticate(uid, secret)
    uid.blank? ? default_client : super
  end
end

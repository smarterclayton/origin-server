require File.expand_path('../../../test_helper', __FILE__)

class RestApiAuthorizationTest < ActiveSupport::TestCase
  include RestApiAuth

  def setup
    with_configured_user
  end

  test 'create authorization' do
    a = Authorization.create :as => @user
    assert a
    assert a.token.present?
    assert a.created_at > 10.seconds.ago
    assert a.note.blank?
    assert a.expires_in_seconds > 100
    assert a.expires_in - a.expires_in_seconds < 2
    assert !a.expired?
    assert a.scopes.length > 0
    assert a.scopes.include?(:userinfo)
    assert a.identity.present?
  end

  test 'create session authorization' do
    assert a = Authorization.create(:scopes => :session, :as => @user)
    assert a.scopes.include?(:session)
  end

  test 'authorizations list changes' do
    assert_difference 'Authorization.all(:as => @user).count' do
      Authorization.create :as => @user
    end
    auths = Authorization.all(:as => @user)
    auth = auths.last
    assert auth.token.present?
  end
end

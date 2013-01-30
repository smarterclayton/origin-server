require File.expand_path('../../../test_helper', __FILE__)

class RestApiAuthorizationTest < ActiveSupport::TestCase
  include RestApiAuth

  def setup
    with_configured_user
  end

  test 'create authorization' do
    assert a = Authorization.create(:as => @user)
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

  test 'authorization allows authentication' do
    assert a = Authorization.create(:as => @user)
    assert User.find(:one, :as => a)
  end

  test 'uses reasonable expiration limit' do
    assert a = Authorization.create(:expires_in => 10.minutes.seconds, :as => @user)
    assert_equal 10.minutes.seconds, a.expires_in
  end

  test 'limits expiration' do
    assert a = Authorization.create(:expires_in => 1.days.seconds, :as => @user)
    assert_not_equal 1.days.seconds, a.expires_in
  end

  test 'negative expiration' do
    assert a = Authorization.create(:expires_in => -1, :as => @user)
    assert a.expires_in > 0
  end

  test 'reuse authorization' do
    assert a = Authorization.create(:as => @user)
    assert b = Authorization.create(:reuse => true, :as => @user)
    assert_equal b.id, a.id
  end

  test 'reuse needs identical scopes' do
    assert a = Authorization.create(:as => @user)
    assert b = Authorization.create(:scope => :session, :reuse => true, :as => @user)
    assert_not_equal b.id, a.id
  end

  test 'reuse needs identical notes' do
    assert a = Authorization.create(:as => @user)
    assert b = Authorization.create(:note => 'bar', :reuse => true, :as => @user)
    assert_not_equal b.id, a.id
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

  test 'authorization delete all' do
    assert Authorization.create(:as => @user)
    assert Authorization.destroy_all(:as => @user)
    assert Authorization.all(:as => @user).empty?
  end

  test 'update authorization' do
    assert a = Authorization.create(:note => 'foo', :as => @user)
    a.note = 'bar'
    assert a.save
    assert_equal 'bar', Authorization.first(:as => @user).note
  end
end

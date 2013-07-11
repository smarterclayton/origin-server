ENV["TEST_NAME"] = "functional_app_events_controller_test"
require 'test_helper'
class AppEventsControllerTest < ActionController::TestCase
  
  def setup
    @controller = AppEventsController.new
    
    @random = rand(1000000000)
    @login = "user#{@random}"
    @password = "password"
    @user = CloudUser.new(login: @login)
    @user.capabilities["private_ssl_certificates"] = true
    @user.save
    Lock.create_lock(@user)
    register_user(@login, @password)
    
    @request.env['HTTP_AUTHORIZATION'] = "Basic " + Base64.encode64("#{@login}:#{@password}")
    @request.env['HTTP_ACCEPT'] = "application/json"
    stubber
    @namespace = "ns#{@random}"
    @domain = Domain.new(namespace: @namespace, owner:@user)
    @domain.save
    @app_name = "app#{@random}"
    @app = Application.create_app(@app_name, [PHP_VERSION], @domain, nil, true)
    @app.save
  end
  
  def teardown
    begin
      @user.force_delete
    rescue
    end
  end
  
  test "app events" do
    server_alias = "as#{@random}"
    post :create, {"event" => "stop", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "start", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "restart", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "force-stop", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "scale-up", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "scale-down", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "reload", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "thread-dump", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :unprocessable_entity
    post :create, {"event" => "tidy", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    as = "as.#{@random}"
    post :create, {"event" => "add-alias", "alias" => as, "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
    post :create, {"event" => "remove-alias", "alias" => as, "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :success
  end
  
  test "no app or domain id" do
    post :create, {"event" => "stop", "application_id" => @app.name}
    assert_response :not_found
    post :create, {"event" => "stop", "domain_id" => @domain.namespace}
    assert_response :not_found
  end
  
  test "no or wrong alias" do
    post :create, {"event" => "add-alias", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :unprocessable_entity
    post :create, {"event" => "remove-alias", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :unprocessable_entity
    post :create, {"event" => "remove-alias", "alias" => "bogus", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :not_found
  end
  
  test "wrong event type" do
    post :create, {"event" => "bogus", "domain_id" => @domain.namespace, "application_id" => @app.name}
    assert_response :unprocessable_entity
  end
  
  test "thread-dump on a cartridge with threaddump hook" do
    #create an app with threaddump hook i.e. ruby-1.8 or jbossews-2.0
    app_name = "rubyapp#{@random}"
    ruby_app = Application.create_app(app_name, [RUBY_VERSION], @domain, nil, true)
    ruby_app.save
    post :create, {"event" => "thread-dump", "domain_id" => @domain.namespace, "application_id" => ruby_app.name}
    assert_response :success
  end
end

OmniAuth.configure do |c|
  c.logger = Rails.logger
  c.on_failure = Proc.new do |env|
    OmniAuth::FailureEndpoint.new(env).redirect_to_failure
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer unless Rails.env.production?
  provider :http_basic, 'http://127.0.0.1:3001/test/callbacks/basic_auth'
  provider :streamline, 'https://streamline-proxy1.ops.rhcloud.com/wapps/streamline/login.html', 
                        '/login',
                        :http => {:ssl => {:verify => false}}

end

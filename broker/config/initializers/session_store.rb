# Be sure to restart your server when you modify this file.
Broker::Application.config.session_store :cookie_store, :key => 'openshift_session',
                                                        :secure => !Rails.env.development?,
                                                        :http_only => true, # Don't allow Javascript to access the cookie (mitigates cookie-based XSS exploits)
                                                        :expire_after => nil

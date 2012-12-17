require 'faraday'
require 'multi_json'
require 'cgi'
require 'cgi/cookie'

module OmniAuth
  module Strategies
    class Streamline
      include OmniAuth::Strategy

      args [:endpoint, :login]
      option :headers, {}
      option :http, {}

      uid{ raw_info['login'] }
      info do
        prune!({
          'name' => uid,
        })
      end
      credentials do
        prune!({
          'token' => sso_cookie,
          'token_domain' => sso_cookie_domain,
        })
      end
      extra do
        prune!({
          'roles' => raw_info['roles'],
        })
      end

      def sso_cookie
        cookies['rh_sso'].first
      end
      def sso_cookie_domain
        cookies['Domain'].first
      end

      def raw_info
        @raw_info ||= MultiJson.load(authentication_response.body)
      end

      def request_phase
        redirect(login_uri)
      end

      def callback_phase
        return fail!(:service_error) if !authentication_response
        return fail!(:invalid_credentials) if authentication_response.status == 401
        return fail!(:service_error) if authentication_response.status >= 500
        raw_info rescue return fail!(:service_error, $!)

        super
      end

      def fail!(message_key, exception = nil)
        log :error, "Authentication failure! #{message_key} encountered. #{exception.message if exception}"
        redirect(login_uri(:error => message_key))
        #"#{options[:login]}?error=#{message_key}")
      end

      protected

        def prune!(hash)
          hash.delete_if do |_, value|
            prune!(value) if value.is_a?(Hash)
            value.nil? || (value.respond_to?(:empty?) && value.empty?)
          end
        end

        # by default we use static uri. If dynamic uri is required, override
        # this method.
        def api_uri
          options.endpoint
        end

        def login_uri(query={})
          Addressable::URI.parse(options.login).tap do |uri|
            uri.merge(:query_values => prune!(query))
          end.to_s
        end

        def username
          request['username']
        end

        def password
          request['password']
        end

        def cookies
          @cookies ||= Hash[*CGI::Cookie.parse(authentication_response.headers['set-cookie'] || '').flatten]
        end

        def authentication_response
          unless @authentication_response
            return unless username && password

            @authentication_response = Faraday.new(options.http.deep_symbolize_keys) do |conn|
              conn.request :url_encoded
              conn.adapter Faraday.default_adapter
            end.post do |req|
              req.url api_uri
              req.body = {:login => username, :password => password}
            end

            log :debug, "Response from Streamline: #{@authentication_response.status}"
          end

          @authentication_response
        end
    end
  end
end

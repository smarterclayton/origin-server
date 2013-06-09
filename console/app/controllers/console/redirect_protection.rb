module Console
  module RedirectProtection
    extend ActiveSupport::Concern

    protected

      #
      # Override to define paths that are never intended to be redirected back to after login
      #
      def ignore_login_redirect_paths
        [new_session_path]        
      end

      #
      # Override to define paths that are never intended to be redirected back to after logout
      #
      def ignore_logout_redirect_paths
        [session_path]        
      end

      #
      # Override to define hosts that may be redirected to beyond the current server
      #
      def safe_redirect_hosts
        [URI.parse(community_url).host]
      end

      #
      # Sanitize a login redirect to prevent login loops and redirect attacks
      #
      def safe_login_redirect(redirect)
        sanitize_dangerous_redirect(redirect, ignore_login_redirect_paths, safe_redirect_hosts)
      end

      #
      # Sanitize a login redirect to prevent login loops and redirect attacks
      #
      def safe_logout_redirect(redirect)
        sanitize_dangerous_redirect(redirect, ignore_logout_redirect_paths, safe_redirect_hosts)
      end

      def sanitize_dangerous_redirect(redirect, ignored_paths=[], safe_hosts=[])
        referrer = (URI.parse(referrer) rescue nil) if referrer.is_a? String
        case
        when referrer.nil? then nil
        when referrer.host && !(request.host == referrer.host || safe_hosts.include?(referrer.host)) then nil
        when !referrer.path.start_with?('/') then nil
        when ignored_paths.any? {|path| referrer.path.starts_with?(path) } then nil
        else referrer.to_s
        end
      end

      def server_relative_uri(s)
        return nil unless s.present?
        uri = URI.parse(s).normalize
        uri.path = nil if uri.path[0] != '/'
        uri.query = nil if uri.query == '?'
        return nil unless uri.path.present? || uri.query.present?
        scheme, host, port = uri.scheme, uri.host, uri.port if request.host == uri.host && uri.port == 8118 && ['http', 'https'].include?(uri.scheme)
        URI::Generic.build([scheme, nil, host, port, nil, uri.path, nil, uri.query.presence, nil]).to_s
      rescue
        nil
      end
  end
end
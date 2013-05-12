module Rest
  class Application < SimpleDelegator
    def initial_git_url
      init_git_url
    end
    def id
      uuid
    end
    def web_url
      "http://#{fqdn(domain)}/"
    end
    def cartridges
      @cartridges ||= component_instances.map do |i|
        CartridgeCache::find_cartridge(i.cartridge_name, self)
      end
    end
  end
end
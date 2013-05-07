module Console::RestApi
  class Environment < Console::RestApi::Base
    allow_anonymous
    singleton
    cacheable

    schema do
      string :domain_suffix
      boolean :download_cartridges_enabled
    end

    cache_find_method :one
  end
end

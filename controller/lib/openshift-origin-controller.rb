require "openshift-origin-common"

module OpenShift
  module Controller
    require 'controller_engine' if defined?(Rails) && Rails::VERSION::MAJOR == 3

    autoload :ApiResponses,            'openshift/controller/api_responses'
    autoload :Authentication,          'openshift/controller/authentication'
  end

  module Auth
    autoload :BrokerKey,               'openshift/auth/broker_key'
  end

  autoload :ApplicationContainerProxy, 'openshift/application_container_proxy'

  autoload :AuthService,               'openshift/auth_service'
  autoload :DnsService,                'openshift/dns_service'
  autoload :DataStore,                 'openshift/data_store'
  autoload :MongoDataStore,            'openshift/mongo_data_store'
end

require "openshift/exceptions"

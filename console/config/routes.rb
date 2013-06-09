Console::Engine.routes.draw do
  match 'help' => 'console_index#help', :via => :get, :as => 'console_help'
  match 'unauthorized' => 'console_index#unauthorized', :via => :get, :as => 'unauthorized'
  match 'server_unavailable' => 'console_index#server_unavailable', :via => :get, :as => 'server_unavailable'

  # Application specific resources
  resources :application_types, :only => [:show, :index], :id => /[^\/]+/
  resources :applications do
    resources :cartridges, :only => [:show, :create, :index], :id => /[^\/]+/
    resources :aliases, :only => [:show, :create, :index, :destroy, :update], :id => /[^\/]+/ do
      get :delete
    end
    resources :cartridge_types, :only => [:show, :index], :id => /[^\/]+/
    resource :restart, :only => [:show, :update], :id => /[^\/]+/

    resource :building, :controller => :building, :id => /[^\/]+/, :only => [:show, :new, :destroy, :create] do
      get :delete
    end

    resource :scaling, :controller => :scaling, :only => [:show, :new] do
      get :delete
      resources :cartridges, :controller => :scaling, :only => [:update], :id => /[^\/]+/, :format => false #, :format => /json|csv|xml|yaml/
    end

    resource :storage, :controller => :storage, :only => [:show] do
      resources :cartridges, :controller => :storage, :only => [:update], :id => /[^\/]+/, :format => false #, :format => /json|csv|xml|yaml/
    end

    member do
      get :delete
      get :get_started
    end
  end

  # Settings page specific resources
  resource :settings, :only => :show
  resource :domain, :id => /[^\/]+/, :only => [:new, :create, :edit, :update]
  resources :keys, :id => /[^\/]+/, :only => [:new, :create, :destroy]
  resources :authorizations, :id => /[^\/]+/, :except => :index
  match 'authorizations' => 'authorizations#destroy_all', :via => :delete

  # Account specific resources
  unless Console.config.disable_account
    resource :account,
             :controller => :account,
             :only => [:show]
  end

  resource :session, :controller => :session, :only => [:new, :create] do
    get :destroy
  end

  root :to => 'console_index#index', :via => :get, :as => :console
end
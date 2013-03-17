Rails.application.routes.draw do
  mount Console::Engine => '/console'
  root :to => 'console/console_index#index'
end

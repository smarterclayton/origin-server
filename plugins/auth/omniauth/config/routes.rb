Rails.application.routes.draw do
  scope '/auth' do
    match ':provider/callback' => 'sessions#create'
    resources :providers, :only => :index
  end
end

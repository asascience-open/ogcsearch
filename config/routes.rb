Ogcsearch::Application.routes.draw do

  namespace :admin do
    resources :wms, :only => [:index, :destroy] do
      get 'populate', :on => :collection
    end
  end

  match 'wms/find.:format' => 'wms#find'
  match 'wms/parse' => 'wms#parse'
  match 'wms/status.:format' => 'wms#status'
  match 'wms/search.:format' => 'wms#search'

  root :to => "client#index"

end

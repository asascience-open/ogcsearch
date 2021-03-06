OgcSearch::Application.routes.draw do

  namespace :admin do
    resources :wms, :only => [:index, :destroy] do
      get 'populate', :on => :collection
    end
    resources :job, :only => [:index, :destroy] do
      get 'populate', :on => :collection
    end
    resources :kmx, :only => [:index, :destroy] do
      get 'populate', :on => :collection
    end
  end

  resources :extract, :only => [:index]

  match 'wms/find.:format' => 'wms#find'
  match 'wms/parse' => 'wms#parse'
  match 'wms/status.:format' => 'wms#status'
  match 'wms/search.:format' => 'wms#search'
  match 'wms/extract.:format' => 'wms#extract'

  match 'kmx/find.:format' => 'kmx#find'
  match 'kmx/parse' => 'kmx#parse'
  match 'kmx/status.:format' => 'kmx#status'
  match 'kmx/search.:format' => 'kmx#search'
  match 'kmx/extract.:format' => 'kmx#extract'

  match 'client' => 'client#index'

  match 'proxy' => 'client#proxy', :via => [:get, :post]

  root :to => "client#index"

end

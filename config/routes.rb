Ogcsearch::Application.routes.draw do

  namespace :admin do
    resources :wms
  end

  match 'wms/find.:format' => 'wms#find'
  match 'wms/parse' => 'wms#parse'
  match 'wms/status.:format' => 'wms#status'
  match 'wms/search.:format' => 'wms#search'
  match 'wms/index.:format' => 'wms#index'
  match 'wms/populate.:format' => 'wms#populate'

  root :to => "client#index"

end

namespace :ogc do
  desc "Clean WMS Servers (removes all WMS Servers)"
  task :clean_wms => :environment do
    WmsServer.destroy_all
  end
end

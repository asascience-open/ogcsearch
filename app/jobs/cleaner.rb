class Cleaner < GlobalJob
  def perform
    # Non active WmsServers
    WmsServer.not_active.each do |s|
      # TODO: Send an email about the hung WMS Server
    end

    # If the WmsServer is locked and has not been updated in a day, it is probably hung on something
    hung_servers = WmsServer.not_active_since(1.day.ago).select{|s|s.locked?}
    hung_servers.each do |s|
      # Remove the servers jobs
      s.remove_jobs
      # TODO: Send an email about the hung WMS Server

      # Try the parsing again
      s.parse
    end
  end
end

class Job
  include Mongoid::Document
  
  store_in :delayed_backend_mongoid_jobs
end

class Job
  include Mongoid::Document

  field :type,              type: String
  field :data,              type: String

  store_in :delayed_backend_mongoid_jobs

end

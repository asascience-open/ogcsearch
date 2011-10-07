class Job
  include Mongoid::Document

  field :job_type,          type: String
  field :job_data,          type: String

  scope :pending, where(:locked_at => nil)
  scope :failed, where(:failed_at.ne => nil)
  scope :locked, where(:locked_at.ne => nil)

  store_in :delayed_backend_mongoid_jobs

  def DT_RowId
    self.id.to_s
  end

end

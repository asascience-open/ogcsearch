class GlobalJob

  # Call back to save Job data
  def enqueue(job)
    job[:job_type] = self.class.to_s
    job[:job_data] = @job_data
    job.save
  end

  def job_data=(job_data)
    @job_data = job_data
  end

end

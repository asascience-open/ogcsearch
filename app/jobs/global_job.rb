class GlobalJob

  # Call back to save Job data
  def enqueue(job)
    job[:job_type] = self.class.to_s
    job[:data] = @data
    job.save
  end

  def data=(data)
    @data = data
  end

end

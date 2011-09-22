class GlobalJob

  def enqueue(job)
    job[:type] = self.class.to_s
    job[:data] = @data
    job.save
  end

  def data=(data)
    @data = data
  end

end

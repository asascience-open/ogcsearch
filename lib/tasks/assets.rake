task 'assets:precompile' => 'assets:stub_mongoid'

task 'assets:stub_mongoid' do
  def Mongoid.load!(*args)
    true
  end
end

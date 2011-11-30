source 'http://rubygems.org'

gem 'rails', '3.1.1'
gem 'rake'

# Database
gem 'bson'
gem 'bson_ext'
gem 'mongo', '1.4.0'
gem 'mongoid'
gem 'mongoid_spacial'
# This fork supports embedded document voting
gem 'voteable_mongo', :git => 'http://github.com/angelim/voteable_mongo.git'

# DJ
gem 'delayed_job', '2.1.4'
# There was a nil bug when running with Mongo 2.0+, fixed in a commit, but not released
gem 'delayed_job_mongoid', :git => "http://github.com/collectiveidea/delayed_job_mongoid", :ref => "77fa22a7ad"

# Searching
# https://github.com/aaw/mongoid_fulltext
gem 'mongoid_fulltext'

group :assets do
  gem 'sass-rails',   '~> 3.1.4'
  gem 'coffee-rails', '~> 3.1.1'
  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

group :test do
  gem 'turn', :require => false
end

# Webserver
gem 'unicorn'

# Deployment
gem 'heroku'

# Caching
gem 'dalli'

# Paging
gem 'kaminari'

# Application
gem 'nokogiri'
gem 'rgeo' # Requires 'proj-devel' and 'geos-devel'
gem 'rgeo-geojson'

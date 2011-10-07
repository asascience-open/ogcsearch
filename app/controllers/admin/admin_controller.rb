class Admin::AdminController < ApplicationController

  before_filter :verify_access
  layout 'admin'

  def verify_access
    authenticate_or_request_with_http_basic("Restricted Access") do |username, password|
      username == 'admin'
      password == ENV['WEB_ADMIN_PASSWORD']
    end if Rails.env.production? || Rails.env.staging?

  end

end

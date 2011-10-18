class ClientController < ApplicationController

  require 'uri'
  require 'net/http'
  require 'net/https'

  skip_before_filter :verify_authenticity_token, :only => [:proxy]

  def index
  end

  def proxy
    uri = URI.parse(params[:u])
    if [URI::HTTP, URI::HTTPS].include?(uri.class)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.class == URI::HTTPS
      data = http.request(Net::HTTP::Get.new(uri.request_uri))
      headers["Content-Type"] = data.content_type || "text/plain"
      @resp = data.body
      @resp = ActiveSupport::JSON.decode(CGI.unescape(@resp)) if headers["Content-Type"] == "application/json" || headers["Content-Type"] == "text/json"
    else
      headers["Content-Type"] = "application/json"
      @resp = {"status" => "Bad URL"}
    end
    if headers["Content-Type"] == "application/json" || headers["Content-Type"] == "text/json"
      render :json => @resp
    elsif headers["Content-Type"] == "application/xml" || headers["Content-Type"] == "text/xml"
      render :xml => @resp
    else
      render :layout => false
    end

  end

end

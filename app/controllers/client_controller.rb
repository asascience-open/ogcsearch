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
      @resp = JSON.decode(CGI::unescape(data.body))
    else
      @resp = {"status" => "Bad URL"}
    end
    render :layout => false
  end

end

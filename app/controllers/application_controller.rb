class ApplicationController < ActionController::Base
  protect_from_forgery

  protected
    def normalize_url
      @fixed_url = WmsServer.normalize_url(params[:url])
      if @fixed_url.blank? || @fixed_url.nil?
        render :json => {:status => "Invalid URL parameter"}
      end
    end
end

class WmsController < ApplicationController

  def find
    fixed_url = WmsServer.normalize_url(params[:url])
    server = WmsServer.where(url: fixed_url).first
    server = [nil] if server.nil?
    respond_to do |format|
      format.json { render :json => server }
      format.xml { render :xml => server }
    end
  end

  def parse
    fixed_url = WmsServer.normalize_url(params[:url])
    server = WmsServer.find_or_create_by(url: fixed_url)
    #server.save!
    if server.locked?
      render :text => "Server is already being processed", :status => 202
    else
      server.parse
      render :text => "Parsing Started", :status => 202
    end
  end

  def status
    fixed_url = WmsServer.normalize_url(params[:url])
    server = WmsServer.where(url: fixed_url).first
    if server.locked?
      render :text => server.status, :status => 202
    else
      render :text => "OK", :status => 202
    end
  end

  def search
    layers = WmsLayer.fulltext_search(params[:terms])
    respond_to do |format|
      format.json { render :json => layers }
      format.xml { render :xml => layers }
    end
  end

end

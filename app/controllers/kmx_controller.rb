class KmxController < ApplicationController

  before_filter :normalize_url, :only => [:find, :parse, :status, :extract]

  def find
    server = Kmx.includes(:placemarks).where(url: @fixed_url).first
    server = [nil] if server.nil?
    respond_to do |format|
      format.json { render :json => server.as_json(
          :only => [:id, :name, :description, :url],
          :methods => [:likes_json],
          :include => { 
            :placemarks => {
              :only => [nil],
              :methods => [:geojson]
            }
          }
        )}
    end
  end

  def parse
    server = Kmx.find_or_create_by(url: @fixed_url)
    server.tags << params[:terms] unless params[:terms].nil? || server.tags.include?(params[:terms])
    server.save
    if server.locked?
      render :json => {:status => "ALREADY PROCESSING"}, :status => :ok
    else
      server.parse if (params[:force] || server.scanned.nil? || server.scanned < 1.day.ago)
      render :json => {:status => "OK"}, :status => :ok
    end
  end

  def status
    server = Kmx.where(url: @fixed_url).first
    if server.nil?
      render :json => {:status => "SERVER UNKNOWN"}, :status => :ok
    elsif server.locked?
      render :json => {:status => "LOCKED"}, :status => :ok
    else
      render :json => {:status => "OK"}, :status => :ok
    end
  end

  def search
    layers = Kmx.fulltext_search(params[:terms])
    params[:page] ||= 1
    layers = Kaminari.paginate_array(layers).page(params[:page]).per(SEARCH_PER_PAGE)
    respond_to do |format|
      format.json { render :json => {
        }
      }
    end
  end

  def extract
    file = open(@fixed_url)
    r = file.read
    hrefs = Kmx.extract(@fixed_url, r).uniq
    respond_to do |format|
      format.json { render :json => hrefs }
    end
  end
end
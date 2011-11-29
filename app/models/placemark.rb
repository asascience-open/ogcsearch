require 'rgeo/geo_json'

class Placemark

  include Mongoid::Document

  embedded_in :kmx

  field :name,            type: String
  field :description,     type: String
  field :multi,           type: String

  def geojson
    removals = ["multi"]
    s = self.attributes.clone.delete_if {|key, value| removals.include?(key) }
    fac = RGeo::Geographic.spherical_factory(:srid => 4326)
    feat = RGeo::GeoJSON::Feature.new(fac.parse_wkt(self.multi), self.id.to_s, s)
    RGeo::GeoJSON.encode(feat)
  end
end
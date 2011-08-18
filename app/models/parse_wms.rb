require 'open-uri'

class ParseWms < Struct.new(:id)
  def perform
    # Get the WmsServer
    server = WmsServer.find(id)
    server.status = "Processing"
    server.save!
    
    doc = Nokogiri::XML(open(server.url))
    
    # Metadata
    server.name = doc.xpath("//Service/Name").text.strip
    server.title = doc.xpath("//Service/Title").text.strip
    server.abstract = doc.xpath("//Service/Abstract").text.strip
    server.keywords = doc.xpath("//Service/KeywordList/Keyword").collect{|c|c.text.strip}
    server.contact = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactPerson").text.strip
    server.phone = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactVoiceTelephone").text.strip
    server.institution = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactOrganization").text.strip
    server.email = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactElectronicMailAddress").text.strip
    
    # Formats
    server.map_formats = doc.xpath("//Capability/Request/GetMap/Format").collect{|c|c.text.strip}
    server.feature_formats = doc.xpath("//Capability/Request/GetFeatureInfo/Format").collect{|c|c.text.strip}
    server.legend_formats = doc.xpath("//Capability/Request/GetLegendGraphic/Format").collect{|c|c.text.strip}
    server.exceptions = doc.xpath("//Capability/Exception/Format").collect{|c|c.text.strip}
    
    # Global Layer Projections from the first layer
    server.projections = doc.xpath("//Capability/Layer[1]/SRS").collect{|c|c.text.strip}
    
    # Individual Layers
    server.WmsLayers.delete_all
    doc.xpath("//Layer").each do |xl|
      layer = server.WmsLayers.new
      server.WmsLayers.delete(layer) unless process_layer(xl, layer)
    end
    server.status = nil
    server.save!
  end
  
  def process_layer (xl, layer)
  
    # Throw away layers that are layer containers
    return false unless xl.xpath("Layer").empty?
  
    # Queryable
    layer.queryable = xl[:queryable] == 1.to_s ? true : false
    layer.name = xl.xpath("Name").text
    layer.title = xl.xpath("Title").text
    layer.abstract = xl.xpath("Abstract").text
    layer.keywords = xl.xpath("KeywordList/Keyword").collect{|c|c.text}
    
    # BBox
    lbbox = xl.xpath("LatLonBoundingBox").first
    if lbbox.nil?
      lminx,lminy,lmaxx,lmaxy = -180,-90,180,90
    else
      lminx,lminy,lmaxx,lmaxy = lbbox[:minx],lbbox[:miny],lbbox[:maxx],lbbox[:maxy]
    end
    # Normalize the lat and lon through the 'rgeo' gem
    factory = RGeo::Geographic.spherical_factory(:srid => 4326)
    ll = factory.point(lminx,lminy)
    ur = factory.point(lmaxx,lmaxy)
    layer.ll = {:lat => ll.lat, :lng => ll.lon}
    layer.ur = {:lat => ur.lat, :lng => ur.lon}
    bbox =  RGeo::Cartesian::BoundingBox.new(factory)
    layer.bbox = bbox.add(ll).add(ur).to_geometry.as_text
    
    # Elevation and Time
    layer.WmsExtents.delete_all
    xl.xpath("Extent").each do |ext|
      extent = WmsExtent.new
      layer.WmsExtents << extent
      extent.name = ext[:name]
      extent.default_value = ext[:default]
      extent.values = ext.text.split(",")
      extent.nearest_value = xl[:nearestValue] == 1.to_s ? true : false
      extent.multiple_values = xl[:mutipleValues] == 1.to_s ? true : false
      extent.current = xl[:current] == 1.to_s ? true : false
      extent.save!
    end
    
    # Styles
    layer.WmsStyles.delete_all
    xl.xpath("Style").each do |sty|
      style = WmsStyle.new
      layer.WmsStyles << style
      style.name = sty.xpath("Name").text
      style.title = sty.xpath("Title").text
      style.abstract = sty.xpath("Abstract").text
      style.legend_width = sty.xpath("LegendURL").first[:width]
      style.legend_height = sty.xpath("LegendURL").first[:height]
      style.legend_format = sty.xpath("LegendURL/Format").text
      style.legend_url = sty.xpath("LegendURL/OnlineResource").first[:href]
      style.save!
    end
    return layer.save
  end
end

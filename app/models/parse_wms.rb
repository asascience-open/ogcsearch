require 'open-uri'

class ParseWms < Struct.new(:id)
  def perform
    # Get the WmsServer
    server = WmsServer.find(id)
    server.status = "Processing"
    server.save!
    
    doc = Nokogiri::XML(open(server.url))
    
    # Metadata
    server.name = doc.xpath("//Service/Name").text
    server.title = doc.xpath("//Service/Title").text
    server.abstract = doc.xpath("//Service/Abstract").text
    server.keywords = doc.xpath("//Service/KeywordList/Keyword").collect{|c|c.text}
    server.contact = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactPerson").text
    server.phone = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactVoiceTelephone").text
    server.institution = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactOrganization").text
    server.email = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactElectronicMailAddress").text
    
    # Formats
    server.map_formats = doc.xpath("//Capability/Request/GetMap/Format").collect{|c|c.text}
    server.feature_formats = doc.xpath("//Capability/Request/GetFeatureInfo/Format").collect{|c|c.text}
    server.legend_formats = doc.xpath("//Capability/Request/GetLegendGraphic/Format").collect{|c|c.text}
    server.exceptions = doc.xpath("//Capability/Exception/Format").collect{|c|c.text}
    
    # BBox
    bbox = doc.xpath("//Capability/Layer/LatLonBoundingBox").first
    minx = bbox.nil? ? -180 : bbox[:minx]
    miny = bbox.nil? ?  -90 : bbox[:miny]
    maxx = bbox.nil? ?  180 : bbox[:maxx]
    maxy = bbox.nil? ?   90 : bbox[:maxy]
    ll = {:lat => miny, :lng => minx}
    ur = {:lat => maxy, :lng => maxx}    
    server.ll = ll
    server.ur = ur

    # Global Layer Projections
    server.projections = doc.xpath("//Capability/Layer/SRS").collect{|c|c.text}
    
    # Individual Layers
    server.WmsLayers.delete_all
    doc.xpath("//Capability/Layer/Layer").each do |xl|
      layer = WmsLayer.new
      server.WmsLayers << layer
      # Queryable
      layer.queryable = xl[:queryable] == 1.to_s ? true : false
      layer.name = xl.xpath("Name").text
      layer.title = xl.xpath("Title").text
      layer.abstract = xl.xpath("Abstract").text
      layer.keywords = xl.xpath("KeywordList/Keyword").collect{|c|c.text}
      
      # BBox - Set to servers BBox if not defined on the layer
      lbbox = xl.xpath("LatLonBoundingBox").first
      lminx = lbbox.nil? ? minx : lbbox[:minx]
      lminy = lbbox.nil? ? miny : lbbox[:miny]
      lmaxx = lbbox.nil? ? maxx : lbbox[:maxx]
      lmaxy = lbbox.nil? ? maxy : lbbox[:maxy]
      layer_ll = {:lat => lminy, :lng => lminx}
      layer_ur = {:lat => lmaxy, :lng => lmaxx}
      layer.ll = layer_ll
      layer.ur = layer_ur
      
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
      layer.save!
    end
    
    server.status = nil
    server.save!
  end
end

require 'open-uri'

class ParseWms < Struct.new(:id)
  def perform
    # Get the WmsServer
    server = WmsServer.find(id)

    doc = Nokogiri::XML(open(server.url))

    # Metadata
    server.name = doc.xpath("//Service/Name").text.strip
    server.title = doc.xpath("//Service/Title").text.strip
    server.abstract = doc.xpath("//Service/Abstract").text.strip
    server.keywords = doc.xpath("//Service/KeywordList/Keyword").map{|c|c.text.strip.downcase}
    server.contact = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactPerson").text.strip
    server.phone = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactVoiceTelephone").text.strip
    server.institution = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactOrganization").text.strip
    server.email = doc.xpath("//Service/ContactInformation/ContactPersonPrimary/ContactElectronicMailAddress").text.strip

    # Formats
    server.map_formats = doc.xpath("//Capability/Request/GetMap/Format").map{|c|c.text.strip}
    server.feature_formats = doc.xpath("//Capability/Request/GetFeatureInfo/Format").map{|c|c.text.strip}
    server.legend_formats = doc.xpath("//Capability/Request/GetLegendGraphic/Format").map{|c|c.text.strip}
    server.exceptions = doc.xpath("//Capability/Exception/Format").map{|c|c.text.strip}

    # Global Layer Projections from the first layer
    server.projections = doc.xpath("//Capability/Layer[1]/SRS").map{|c|c.text.strip}

    # Individual Layers
    server.wms_layers.destroy_all
    doc.xpath("//Layer").each do |xl|
      layer = WmsLayer.create
      process_layer(xl, layer)
      layer.save!
      server.wms_layers << layer
    end
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
    layer.keywords = xl.xpath("KeywordList/Keyword").map{|c|c.text.strip.downcase}

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
    layer.wms_extents.destroy_all
    xl.xpath("Extent").each do |ext|
      extent = layer.wms_extents.build
      extent.name = ext[:name].strip
      extent.default_value = ext[:default].strip
      extent.values = ext.text.split(",").map{|t|t.strip}
      extent.nearest_value = xl[:nearestValue] == 1.to_s ? true : false
      extent.multiple_values = xl[:mutipleValues] == 1.to_s ? true : false
      extent.current = xl[:current] == 1.to_s ? true : false
    end

    # Styles
    layer.wms_styles.destroy_all
    xl.xpath("Style").each do |sty|
      style = layer.wms_styles.build
      style.name = sty.xpath("Name").text.strip
      style.title = sty.xpath("Title").text.strip
      style.abstract = sty.xpath("Abstract").text.strip
      style.legend_width = sty.xpath("LegendURL").first[:width].strip
      style.legend_height = sty.xpath("LegendURL").first[:height].strip
      style.legend_format = sty.xpath("LegendURL/Format").text.strip
      style.legend_url = sty.xpath("LegendURL/OnlineResource").first[:href].strip
    end
    return
  end
end

require 'open-uri'

class ParseWms < GlobalJob

  def initialize(id)
    @wms_server_id = id
  end

  def parse_111(server, doc)
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

    server.wms_layers.destroy_all

    doc.xpath("//Layer").each do |xl|
      # Only leaf layers will be mappable, correct?
      if xl.xpath("Layer").empty?
        layer = WmsLayer.create
        layer.queryable = xl[:queryable] == 1.to_s ? true : false
        layer.name = xl.xpath("Name").text
        layer.title = xl.xpath("Title").text
        layer.abstract = xl.xpath("Abstract").text

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

        # Recurse the parent layers to grab tags and projections
        projections = xl.xpath("SRS").map{|c|c.text.strip} || []
        keywords = xl.xpath("KeywordList/Keyword").map{|c|c.text.strip.downcase} || []
        xp = xl
        while xp.parent.name == "Layer"
          projections << xp.parent.xpath("SRS").map{|c|c.text.strip}
          keywords << xp.parent.xpath("KeywordList/Keyword").map{|c|c.text.strip.downcase}
          keywords << xp.parent.xpath("Title").text
          xp = xp.parent
        end
        layer.projections = projections.flatten.compact.uniq
        layer.keywords = keywords.flatten.compact.uniq

        # Elevation and Time
        layer.wms_extents.destroy_all
        xl.xpath("Extent").each do |ext|
          extent = layer.wms_extents.build
          extent.name = ext[:name]
          extent.default_value = ext[:default]
          extent.values = ext.text.split(",").map{|t|t.strip}
          extent.nearest_value = ext[:nearestValue] == 1.to_s ? true : false
          extent.multiple_values = ext[:mutipleValues] == 1.to_s ? true : false
          extent.current = ext[:current] == 1.to_s ? true : false
        end

        # Styles
        layer.wms_styles.destroy_all
        xl.xpath("Style").each do |sty|
          style = layer.wms_styles.build
          style.name = sty.xpath("Name").text.strip
          style.title = sty.xpath("Title").text.strip
          style.abstract = sty.xpath("Abstract").text.strip
          style.legend_width = sty.xpath("LegendURL/@width").text.strip
          style.legend_height = sty.xpath("LegendURL/@height").text.strip
          style.legend_format = sty.xpath("LegendURL/Format").text.strip
          style.legend_url = sty.xpath("LegendURL/OnlineResource/@href").text.strip
        end

        layer.save!
        server.wms_layers << layer
      end
    end
    server.scanned = Time.now.utc
    server.save!
    return true
  end

  def parse_130(server, doc)
    # Metadata
    server.name = doc.css("Service/Name").text.strip
    server.title = doc.css("Service/Title").text.strip
    server.abstract = doc.css("Service/Abstract").text.strip
    server.keywords = doc.css("Service/KeywordList/Keyword").map{|c|c.text.strip.downcase}
    server.contact = doc.css("Service/ContactInformation/ContactPersonPrimary/ContactPerson").text.strip
    server.phone = doc.css("Service/ContactInformation/ContactPersonPrimary/ContactVoiceTelephone").text.strip
    server.institution = doc.css("Service/ContactInformation/ContactPersonPrimary/ContactOrganization").text.strip
    server.email = doc.css("Service/ContactInformation/ContactPersonPrimary/ContactElectronicMailAddress").text.strip

    # Formats
    server.map_formats = doc.css("Capability/Request/GetMap/Format").map{|c|c.text.strip}
    server.feature_formats = doc.css("Capability/Request/GetFeatureInfo/Format").map{|c|c.text.strip}
    server.legend_formats = doc.css("Capability/Request/GetLegendGraphic/Format").map{|c|c.text.strip}
    server.exceptions = doc.css("Capability/Exception/Format").map{|c|c.text.strip}

    server.wms_layers.destroy_all

    doc.css("Layer").each do |xl|
      # Only leaf layers will be mappable, correct?
      if xl.css("Layer").empty?
        layer = WmsLayer.create
        layer.queryable = xl[:queryable] == 1.to_s ? true : false
        layer.name = xl.at_css("Name").text
        layer.title = xl.at_css("Title").text
        layer.abstract = xl.at_css("Abstract").text

        # BBox
        lbbox = xl.at_css("EX_GeographicBoundingBox")
        if lbbox.nil?
          lminx,lminy,lmaxx,lmaxy = -180,-90,180,90
        else
          lminx = lbbox.at_css("westBoundLongitude").text
          lminy = lbbox.at_css("southBoundLatitude").text
          lmaxx = lbbox.at_css("eastBoundLongitude").text
          lmaxy = lbbox.at_css("northBoundLatitude").text
        end
        # Normalize the lat and lon through the 'rgeo' gem
        factory = RGeo::Geographic.spherical_factory(:srid => 4326)
        ll = factory.point(lminx,lminy)
        ur = factory.point(lmaxx,lmaxy)
        layer.ll = {:lat => ll.lat, :lng => ll.lon}
        layer.ur = {:lat => ur.lat, :lng => ur.lon}
        bbox =  RGeo::Cartesian::BoundingBox.new(factory)
        layer.bbox = bbox.add(ll).add(ur).to_geometry.as_text

        # Recurse the parent layers to grab tags and projections
        projections = xl.css("CRS").map{|c|c.text.strip} || []
        keywords = xl.css("KeywordList Keyword").map{|c|c.text.strip.downcase} || []
        xp = xl
        while xp.parent.name == "Layer"
          projections << xp.parent.css("CRS").map{|c|c.text.strip}
          keywords << xp.parent.css("KeywordList Keyword").map{|c|c.text.strip.downcase}
          keywords << xp.parent.at_css("Title").text
          xp = xp.parent
        end
        layer.projections = projections.flatten.compact.uniq
        layer.keywords = keywords.flatten.compact.uniq

        # Elevation and Time
        layer.wms_extents.destroy_all
        xl.css("Dimension").each do |ext|
          extent = layer.wms_extents.build
          extent.name = ext[:name]
          extent.default_value = ext[:default]
          extent.values = ext.text.split(",").map{|t|t.strip}
          extent.nearest_value = ext[:nearestValue] == 1.to_s ? true : false
          extent.multiple_values = ext[:mutipleValues] == true.to_s ? true : false
          extent.current = ext[:current] == true.to_s ? true : false
          extent.units = ext[:units]
        end

        # Styles
        layer.wms_styles.destroy_all
        xl.css("Style").each do |sty|
          style = layer.wms_styles.build
          style.name = sty.at_css("Name").text.strip
          style.title = sty.at_css("Title").text.strip
          style.abstract = sty.at_css("Abstract").text.strip
          style.legend_width = sty.at_css("LegendURL")[:width].strip
          style.legend_height = sty.at_css("LegendURL")[:height].strip
          style.legend_format = sty.at_css("LegendURL Format").text.strip
          style.legend_url = sty.at_css("LegendURL OnlineResource")[:href].strip
        end

        layer.save!
        server.wms_layers << layer
      end
    end
    server.scanned = Time.now.utc
    server.save!
    return true
  end

  def perform
    # Get the WmsServer, wms_server_id is passed through the ParseWms.new(:wms_server_id => xxx)
    server = WmsServer.find(@wms_server_id)
    doc = Nokogiri::XML(open(server.url))
    version = doc.root.attribute("version").text
    server.version = version
    if version == "1.1.1"
      # WMS 1.1.1
      parse_111(server, doc)
    elsif version == "1.3.0"
      # WMS 1.3.0
      parse_130(server, doc)
    else
      server.status = "WMS server version is not compatible (1.1.1 and 1.3.0 supported).  Found: '#{version}'."
      server.save!
      return false
    end
  end
end

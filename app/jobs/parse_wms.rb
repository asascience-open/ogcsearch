require 'open-uri'

class ParseWms < GlobalJob

  def initialize(id)
    @wms_server_id = id
  end

  def perform
    # Get the WmsServer, wms_server_id is passed through the ParseWms.new(:wms_server_id => xxx)
    server = WmsServer.find(@wms_server_id)

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
        #layer_info = recurse_layers(xl)
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
          extent.name = ext.xpath("@name").text.strip
          extent.default_value = ext.xpath("@default").text.strip
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
  end
end

require 'open-uri'
require 'rgeo/geo_json'
require 'zip/zip'

class ParseKmx < GlobalJob

  def initialize(id)
    @kmx_id = id
  end

  def perform
    server = Kmx.find(@kmx_id)

    doc = nil
    if server.isKmz?
      # KMZ files can only have 1 KML file in them.  See:
      # http://code.google.com/apis/kml/documentation/kmzarchives.html

      # Download the KMZ and extract the KML files from it.
      file = Tempfile.new("temp.kmz")
      file.binmode
      open(server.url) { |data| file.write data.read }
      file.close

      Zip::ZipFile::foreach(file.path) do |zip|
        if zip.to_s =~ KML_LINK_REGEX
          doc = Nokogiri::XML(zip.get_input_stream.read)
          break
        end
      end
      file.unlink
    else
      doc = Nokogiri::XML(open(server.url))
    end

    doc.remove_namespaces!

    server.name = doc.xpath("/kml/Document/name | /kml/Folder/name | /kml/Document/Folder/name").first.text.strip rescue nil
    server.description = doc.xpath("/kml/Document/description | /kml/Folder/description | /kml/Document/Folder/description").first.text.strip rescue nil

    # Parse for Points, Lines, and Polygons
    factory = RGeo::Geographic.spherical_factory(:srid => 4326)
    server.placemarks.destroy_all
    doc.xpath("//Placemark").each do |xl|
      pmk = server.placemarks.build
      pmk.name = xl.xpath("name").text
      pmk.description = xl.xpath("description").text

      # Points
      points = xl.xpath("Point/coordinates").map do |p|
        extract_points(factory, p.text)
      end.flatten

      # Lines
      lines = xl.xpath("LineString/coordinates").map do |lin|
        factory.line_string(extract_points(factory, lin.text))
      end

      # Polygons
      polygons = xl.xpath("Polygon").map do |p|
        outer = p.xpath("outerBoundaryIs/LinearRing/coordinates").map do |otr|
          factory.linear_ring(extract_points(factory, otr.text))
        end.first

        inners = p.xpath("innerBoundaryIs/LinearRing/coordinates").map do |lr|
          factory.linear_ring(extract_points(factory, lr.text))
        end
        factory.polygon(outer,inners)
      end

      pmk.multi = factory.collection(points + lines + polygons).as_text
      pmk.save!
    end

    server.scanned = Time.now.utc
    server.save!
    server.parse(1.day.from_now.utc)
    return true
  end

  def extract_points(factory, str)
    str.strip.split(" ").map do |pts|
      lon_lat = pts.split(",")
      # KML 2.2: Longitude, Latitude, Altitude
      factory.point(lon_lat[0], lon_lat[1])
    end
  end

end

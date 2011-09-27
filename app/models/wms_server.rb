class WmsServer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongo::Voteable
  include Mongoid::FullTextSearch

  has_many :wms_layers, :dependent => :destroy

  # Fields
  field :name,            type: String
  field :title,           type: String
  field :abstract,        type: String
  field :url,             type: String
  field :scanned,         type: DateTime
  field :email,           type: String
  field :contact,         type: String
  field :institution,     type: String
  field :phone,           type: String
  field :projections,     type: Array     #Strings
  field :map_formats,     type: Array     #Strings
  field :feature_formats, type: Array     #Strings
  field :legend_formats,  type: Array     #Strings
  field :exceptions,      type: Array     #Strings

  field :keywords,        type: Array,  default: []
  # User defined
  field :tags,            type: Array,  default: []

  index :url, unique: true

  # Voting
  voteable self, :voting_field => :likes, :up => +1, :down => -1

  # Searching
  def search_fields
    '%s %s %s %s %s %s' % [name, title, abstract, institution, keywords.join(" "), tags.join(" ")]
  end
  fulltext_search_in :search_fields

  # Callbacks
  before_destroy :remove_jobs

  scope :active, -> { where(:scanned.lte => 1.week.ago.utc) }
  scope :not_active, -> { where(:scanned.gt => 1.week.ago.utc) }
  scope :not_active_since, ->(before) { where(:scanned.lte => before.utc) }

  def url=(_url)
    write_attribute(:url, URI.unescape(_url))
  end

  # Provides normalization and validation of URLs in and out of the database
  def self.normalize_url(url)
    return nil if url.nil? || url.blank?
    uri = URI.parse(url)
    return nil unless [URI::HTTP, URI::HTTPS].include?(uri.class)
    URI.unescape(url)
  end

  def parse
    pw = ParseWms.new(self.id)
    pw.data = self.id.to_s
    Delayed::Job.enqueue(pw)
  end

  def locked?
    !Job.where(type: "ParseWms", data: self.id.to_s).empty?
  end

  def likes_json
    self.likes.as_json(:only => ["up", "down"])
  end

  def web_mapping_projections
    WEB_MAPPING_PROJECTIONS & self.projections unless self.projections.nil?
  end

  def remove_jobs
    Job.where(type: "ParseWms", data: self.id.to_s).destroy_all
  end

end

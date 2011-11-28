class Kmx
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongo::Voteable
  include Mongoid::FullTextSearch

  # Fields
  field :name,            type: String
  field :title,           type: String
  field :abstract,        type: String
  field :url,             type: String
  field :scanned,         type: DateTime

  field :keywords,        type: Array,  default: []
  # User defined
  field :tags,            type: Array,  default: []

  # Record messages
  field :status,          type: String

  index :url, unique: true

  # Voting
  voteable self, :voting_field => :likes, :up => +1, :down => -1

  # Searching
  def search_fields
    '%s %s %s %s %s %s' % [name, title, abstract, keywords.join(" "), tags.join(" ")]
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

	def self.extract(url,data)
    # data =  open(@url).read
    data.scan(/([a-zA-Z0-9_\-\.\/:]+\.km[lz]{1})[\W]/i).map do |k|
      # Normalize into a URI. This handles relative links (if needed)
      URI::join(url,k.first).to_s.gsub(/([^:])\/\//, '\1/') rescue nil
    end.compact
  end
 
  def remove_jobs
    Job.where(type: "Kmx", data: self.id.to_s).destroy_all
  end

end
class WmsServer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongo::Voteable
  include Sunspot::Mongoid

  embeds_many :WmsLayers

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

  field :keywords,        type: String
  # User defined
  field :tags,            type: String

  # Voting
  voteable self, :voting_field => :likes, :up => +1, :down => -1

  # Searching
  searchable do
    text :name
    text :title
    text :abstract
    text :institution
    text :tags
    text :keywords
  end

  before_destroy :remove_jobs

  # Provides normalization of URLs in and out of the database
  def self.normalize_url(url)
    url
  end

  def parse
    job = Delayed::Job.enqueue(ParseWms.new(self.id))
    job[:type] = ParseWms.to_s
    job[:data] = self.id.to_s
    job.save
  end

  def locked?
    !Job.where(data: self.id).empty?
  end

  private
    def remove_jobs
      Job.where(data: self.id).destroy_all
    end

end

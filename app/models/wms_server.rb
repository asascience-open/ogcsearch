class WmsServer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Spacial::Document
  include Mongo::Voteable
  include Sunspot::Mongoid

  embeds_many :WmsLayers
  
  # Fields
  field :name,            type: String
  field :title,           type: String
  field :abstract,        type: String
  field :url,             type: String
  field :keywords,        type: Array     #Strings
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
  
  # Locked by a job providing status updates
  field :status,          type: String
  
  # Spatial BBOX as two points
  field :ll,              type: Array,        spacial: true
  field :ur,              type: Array,        spacial: true  
  spacial_index :ll
  spacial_index :ur

  # Voting
  voteable self, :voting_field => :likes, :up => +1, :down => -1
  voteable self, :voting_field => :reliability, :up => +1, :down => -1
  voteable self, :voting_field => :meta, :up => +1, :down => -1
  
  # Searching
  searchable do
    text :name
    text :title
    text :abstract
    text :keywords
    text :institution
  end

  # Provides normalization of URLs in and out of the database
  def self.normalize_url(url)
    url
  end

  def parse
    p self.id
    job = Delayed::Job.enqueue(ParseWms.new(self.id))
  end
  
  def locked?
    !self.status.nil?
  end

end

class WmsServer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Spacial::Document
  include Mongo::Voteable
  include Sunspot::Mongoid

  embeds_many :WmsLayers
  
  # Fields
  field :name,            type: String
  field :url,             type: String
  field :keywords,        type: Array #Strings
  field :scanned,         type: DateTime
  field :email,           type: String
  field :contact,         type: String
  field :institution,     type: String
  field :phone,           type: String
  field :projections,     type: Array #Strings
  
  # Spatial BBOX as two points
  field :ul,              type: Array,        spacial: true
  field :lr,              type: Array,        spacial: true  
  spacial_index :ul
  spacial_index :lr

  # Voting
  voteable self, :voting_field => :likes, :up => +1, :down => -1
  voteable self, :voting_field => :reliability, :up => +1, :down => -1
  voteable self, :voting_field => :metadata, :up => +1, :down => -1
  
  # Searching
  searchable do
    text :name
    text :keywords
    text :institution
  end

end

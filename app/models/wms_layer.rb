class WmsLayer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Spacial::Document
  include Mongo::Voteable
  include Sunspot::Mongoid

  embedded_in :WmsServer
  embeds_many :WmsStyles
  embeds_many :WmsExtents
  
  
  # Fields
  field :name,        type: String
  field :title,       type: String
  field :abstract,    type: String
  field :queryable,   type: Boolean
  field :thumbnail,   type: String
  field :keywords,    type: Array     #Strings
  
  # Spatial BBOX as two points
  field :ll,          type: Array,        spacial: true
  field :ur,          type: Array,        spacial: true
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
  end
  
end

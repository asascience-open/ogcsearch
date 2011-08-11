class WmsLayer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Spacial::Document
  include Mongo::Voteable
  include Sunspot::Mongoid

  embedded_in :WmsServer
  
  # Fields
  field :name,        type: String
  field :summary,     type: String
  field :time,        type: Boolean
  field :queryable,   type: Boolean
  field :elevation,   type: Boolean
  field :thumbnail,   type: String
  field :legend_url,  type: String
  field :keywords,    type: Array #Strings
  field :styles,      type: Array #Strings
  
  # Spatial BBOX as two points
  field :ul,          type: Array,        spacial: true
  field :lr,          type: Array,        spacial: true
  spacial_index :ul
  spacial_index :lr
  
  # Voting
  voteable self, :voting_field => :likes, :up => +1, :down => -1
  voteable self, :voting_field => :reliability, :up => +1, :down => -1
  voteable self, :voting_field => :metadata, :up => +1, :down => -1
  
  # Searching
  searchable do
    text :name
    text :summary
    text :keywords
  end
  
end

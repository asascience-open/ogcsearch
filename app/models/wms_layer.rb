class WmsLayer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Spacial::Document
  include Mongo::Voteable
  include Mongoid::Taggable
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

  field :keywords,    type: String
  # User defined
  field :tags,        type: String

  # Spatial BBOX as two points
  field :ll,          type: Array,        spacial: true
  field :ur,          type: Array,        spacial: true
  spacial_index :ll
  spacial_index :ur
  # BBox as WKT
  field :bbox,        type: String


  # Voting
  voteable self, :voting_field => :likes, :up => +1, :down => -1

  # Searching
  searchable do
    text :name
    text :title
    text :abstract
    text :tags
    text :keywords
  end

end

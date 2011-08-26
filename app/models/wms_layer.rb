class WmsLayer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Spacial::Document
  include Mongo::Voteable
  include Mongoid::FullTextSearch

  belongs_to :wms_server, index: true
  embeds_many :wms_styles
  embeds_many :wms_extents

  # Fields
  field :name,        type: String
  field :title,       type: String
  field :abstract,    type: String
  field :queryable,   type: Boolean
  field :thumbnail,   type: String

  field :keywords,    type: Array,  default: []
  # User defined
  field :tags,        type: Array,  default: []

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
  def search_fields
    '%s %s %s %s %s' % [name, title, abstract, keywords.join(" "), tags.join(" ")]
  end
  fulltext_search_in :search_fields

end

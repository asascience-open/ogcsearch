class WmsStyle
  include Mongoid::Document
  include Mongo::Voteable

  embedded_in :WmsLayer
  
  # Fields
  field :name,            type: String
  field :title,           type: String
  field :abstract,        type: String
  field :legend_format,   type: String
  field :legend_width,    type: String
  field :legend_height,   type: String
  field :legend_url,      type: String
  
end

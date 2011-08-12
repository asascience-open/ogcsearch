class WmsExtent
  include Mongoid::Document

  embedded_in :WmsLayer
  
  # Fields
  field :name,            type: String
  field :units,           type: String
  field :default_value,   type: String
  field :values,          type: Array     # Strings
  field :current,         type: Boolean
  field :nearest_value,   type: Boolean
  field :multiple_values, type: Boolean
  
end

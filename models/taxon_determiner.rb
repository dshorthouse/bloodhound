class TaxonDeterminer < ActiveRecord::Base
   belongs_to :taxon
   belongs_to :agent
end
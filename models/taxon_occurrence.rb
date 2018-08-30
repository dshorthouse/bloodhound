class TaxonOccurrence < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :taxon
end
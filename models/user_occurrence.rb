class UserOccurrence < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :user
   has_one :taxon_occurrence, foreign_key: :occurrence_id, primary_key: :occurrence_id
end
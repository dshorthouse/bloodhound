class UserOccurrence < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :user
   has_one :taxon_occurrence, foreign_key: :occurrence_id, primary_key: :occurrence_id

   before_update :set_update_time

   private

   def set_update_time
     self.updated = Time.now
   end


end
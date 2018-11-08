class UserOccurrence < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :user
   belongs_to :claimant, foreign_key: :created_by, class_name: "User"

   has_one :taxon_occurrence, foreign_key: :occurrence_id, primary_key: :occurrence_id

   before_update :set_update_time

   alias_attribute :user_occurrence_id, :id

   private

   def set_update_time
     self.updated = Time.now
   end

end
class OccurrenceDeterminer < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :agent

   validates :occurrence_id, presence: true
   validates :agent_id, presence: true
end
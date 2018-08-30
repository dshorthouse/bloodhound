class OccurrenceRecorder < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :agent
end
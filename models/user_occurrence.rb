class UserOccurrence < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :user
end
class AgentDescription < ActiveRecord::Base
   belongs_to :agent
   belongs_to :description
end
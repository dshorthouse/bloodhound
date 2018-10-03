class Occurrence < ActiveRecord::Base

  self.primary_key = :gbifID

  has_many :occurrence_determiners
  has_many :determiners, through: :occurrence_determiners, source: :agent

  has_many :occurrence_recorders
  has_many :recorders, through: :occurrence_recorders, source: :agent

  has_many :user_occurrences
  has_many :users, through: :user_occurrences, source: :user

  alias_attribute :gbifID, :id

  def self.enqueue(o)
    Sidekiq::Client.enqueue(Bloodhound::OccurrenceWorker, o)
  end

  def coordinates
    lat = decimalLatitude.to_f
    long = decimalLongitude.to_f
    return nil if lat == 0 || long == 0 || lat > 90 || lat < -90 || long > 180 || long < -180
    [long, lat]
  end

  def agents
    {
      determiners: determiners.map{|d| { id: d[:id], given: d[:given], family: d[:family] } },
      recorders: recorders.map{|d| { id: d[:id], given: d[:given], family: d[:family] } }
    }
  end

  def actions
    identified = user_occurrences.select(:'users.orcid', :'users.given', :'users.family', :'users.email')
                                 .joins(:user)
                                 .where("MATCH (user_occurrences.action) AGAINST ('+identified' IN BOOLEAN MODE)")
                                 .as_json(except: :id)
    recorded = user_occurrences.select(:'users.orcid', :'users.given', :'users.family', :'users.email')
                               .joins(:user)
                               .where("MATCH (user_occurrences.action) AGAINST ('+recorded' IN BOOLEAN MODE)")
                               .as_json(except: :id)
    { identified: identified, recorded: recorded }.deep_symbolize_keys
  end

end
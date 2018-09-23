class Occurrence < ActiveRecord::Base

  has_many :occurrence_determiners
  has_many :determiners, through: :occurrence_determiners, source: :agent

  has_many :occurrence_recorders
  has_many :recorders, through: :occurrence_recorders, source: :agent

  has_many :user_occurrences
  has_many :users, through: :user_occurrences, source: :user

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

end
class Dataset < ActiveRecord::Base
  has_many :occurrences, primary_key: :datasetKey, foreign_key: :datasetKey

  validates :datasetKey, presence: true

  before_update :set_update_time

  def users
    User.joins(occurrences: :dataset)
        .where(datasets: { id: id })
        .where(user_occurrences: { visible: true })
        .distinct
        .order(:family)
  end

  def agents
    recorders = Agent.joins(occurrence_recorders: :occurrence)
                     .where(occurrences: { datasetKey: datasetKey })
    determiners = Agent.joins(occurrence_determiners: :occurrence)
                       .where(occurrences: { datasetKey: datasetKey })
    recorders.union_all(determiners).distinct.order(:family)
  end

  def license_icon
    if license.include?("/zero/")
      "https://i.creativecommons.org/p/mark/1.0/88x31.png"
    elsif license.include?("/by/")
      "https://i.creativecommons.org/l/by/4.0/88x31.png"
    elsif license.include?("/by-nc/")
      "https://i.creativecommons.org/l/by-nc/4.0/88x31.png"
    end
  end

  private

  def set_update_time
    self.updated_at = Time.now
  end

end

class Dataset < ActiveRecord::Base
  has_many :occurrences, primary_key: :datasetKey, foreign_key: :datasetKey

  validates :datasetKey, presence: true

  before_update :set_update_time
  after_create :add_search
  after_update :update_search
  after_destroy :remove_search

  def users
    User.joins(occurrences: :dataset)
        .where(datasets: { id: id })
        .where(user_occurrences: { visible: true })
        .distinct
  end

  def user_occurrences
    UserOccurrence.joins(:user)
                  .joins(occurrence: :dataset)
                  .where(datasets: { id: id })
                  .where(user_occurrences: { visible: true })
  end

  def claimed_occurrences
    UserOccurrence.select("user_occurrences.id", "occurrences.*")
                  .joins(occurrence: :dataset)
                  .where(datasets: { id: id })
                  .where(user_occurrences: { visible: true })
  end

  def agents
    determiners = OccurrenceDeterminer
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: {datasetKey: datasetKey })
                    .distinct
    recorders = OccurrenceRecorder
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: {datasetKey: datasetKey })
                    .distinct
    combined = recorders
                    .union_all(determiners)
                    .unscope(:order)
                    .select(:agent_id)
                    .distinct
    Agent.where(id: combined).order(:family)
  end

  def agents_occurrence_counts
    determiners = OccurrenceDeterminer
                    .joins(:occurrence)
                    .where(occurrences: {datasetKey: datasetKey })
    recorders = OccurrenceRecorder
                    .joins(:occurrence)
                    .where(occurrences: {datasetKey: datasetKey })
    combined = recorders
                    .union(determiners)
                    .group(:agent_id)
                    .order(Arel.sql("count(*) desc"))
                    .count
  end

  def agents_occurrence_count
    determiners = OccurrenceDeterminer
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: {datasetKey: datasetKey })
                    .distinct
    recorders = OccurrenceRecorder
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: {datasetKey: datasetKey })
                    .distinct
    recorders.union_all(determiners)
             .unscope(:order)
             .select(:agent_id)
             .distinct
             .count
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

  def add_search
    es = Bloodhound::ElasticIndexer.new
    if !es.get_dataset(self)
      es.add_dataset(self)
    end
  end

  def update_search
    es = Bloodhound::ElasticIndexer.new
    es.update_dataset(self)
  end

  def remove_search
    es = Bloodhound::ElasticIndexer.new
    begin
      es.delete_dataset(self)
    rescue
    end
  end

end

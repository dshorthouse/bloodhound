class Dataset < ActiveRecord::Base
  has_many :occurrences, primary_key: :datasetKey, foreign_key: :datasetKey

  validates :datasetKey, presence: true

  before_update :set_update_time
  after_create :add_search
  after_update :update_search
  after_destroy :remove_search

  def has_claim?
    UserOccurrence.from("user_occurrences FORCE INDEX (user_occurrence_idx)")
                  .joins(:occurrence)
                  .where(occurrences: { datasetKey: datasetKey })
                  .limit(1).exists?
  end

  alias_method :has_user?, :has_claim?

  def has_agent?
    determiner = OccurrenceDeterminer
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: { datasetKey: datasetKey }).limit(1)
    recorder = OccurrenceRecorder
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: { datasetKey: datasetKey }).limit(1)
    determiner.exists? || recorder.exists?
  end

  def users
    User.joins("INNER JOIN ( SELECT DISTINCT
              user_occurrences.user_id, user_occurrences.visible
            FROM
              user_occurrences FORCE INDEX (user_occurrence_idx)
            INNER JOIN
              occurrences ON occurrences.gbifID = user_occurrences.occurrence_id
            WHERE
              occurrences.datasetKey = '#{datasetKey}'
            ) a ON a.user_id = users.id")
        .where("a.visible = true")
  end

  def user_ids
    User.select(:id)
        .joins("INNER JOIN ( SELECT DISTINCT
              user_occurrences.user_id, user_occurrences.visible
            FROM
              user_occurrences FORCE INDEX (user_occurrence_idx)
            INNER JOIN
              occurrences ON occurrences.gbifID = user_occurrences.occurrence_id
            WHERE
              occurrences.datasetKey = '#{datasetKey}'
            ) a ON a.user_id = users.id")
        .where("a.visible = true")
  end

  def user_occurrences
    UserOccurrence.joins(:user)
                  .joins(:claimant)
                  .joins(:occurrence)
                  .where(occurrences: { datasetKey: datasetKey })
  end

  def claimed_occurrences
    UserOccurrence.select(:id, :visible, "occurrences.*")
                  .joins(:occurrence)
                  .where(occurrences: { datasetKey: datasetKey })
  end

  def agents
    determiners = OccurrenceDeterminer
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: { datasetKey: datasetKey })
    recorders = OccurrenceRecorder
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: { datasetKey: datasetKey })
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
                    .where(occurrences: { datasetKey: datasetKey })
    recorders = OccurrenceRecorder
                    .joins(:occurrence)
                    .where(occurrences: { datasetKey: datasetKey })
    recorders.union(determiners)
             .group(:agent_id)
             .order(Arel.sql("count(*) desc"))
             .count
  end

  def agents_occurrence_count
    determiners = OccurrenceDeterminer
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: { datasetKey: datasetKey })
                    .distinct
    recorders = OccurrenceRecorder
                    .select(:agent_id)
                    .joins(:occurrence)
                    .where(occurrences: { datasetKey: datasetKey })
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
    es = Bloodhound::ElasticDataset.new
    if !es.get(self)
      es.add(self)
    end
  end

  def update_search
    es = Bloodhound::ElasticDataset.new
    es.update(self)
  end

  def remove_search
    es = Bloodhound::ElasticDataset.new
    begin
      es.delete(self)
    rescue
    end
  end

end

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
             .joins(:agent)
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

  def agents_occurrence_unclaimed_counts
    determiners = OccurrenceDeterminer
                    .joins(:occurrence)
                    .left_outer_joins(occurrence: :user_occurrences)
                    .where(occurrences: { datasetKey: datasetKey })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders = OccurrenceRecorder
                    .joins(:occurrence)
                    .left_outer_joins(occurrence: :user_occurrences)
                    .where(occurrences: { datasetKey: datasetKey })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders.union(determiners)
             .group(:agent_id)
             .order(Arel.sql("count(*) desc"))
             .count
  end

  def trainers
    trainers = User.joins("INNER JOIN ( SELECT DISTINCT
              user_occurrences.created_by, user_occurrences.visible
            FROM
              user_occurrences FORCE INDEX (user_occurrence_idx)
            INNER JOIN
              occurrences ON occurrences.gbifID = user_occurrences.occurrence_id
            WHERE
              occurrences.datasetKey = '#{datasetKey}'
            AND
              user_occurrences.created_by NOT IN (#{User::BOT_IDS.join(",")})
            AND
              user_occurrences.created_by != user_occurrences.user_id
            ) a ON a.created_by = users.id")
        .where("a.visible = true")
  end

  def license_icon(form = "button")
    size = (form == "button") ? "88x31" : "80x15"
    if license.include?("/zero/")
      url = "https://i.creativecommons.org/p/zero/1.0/#{size}.png"
    elsif license.include?("/by/")
      url = "https://i.creativecommons.org/l/by/4.0/#{size}.png"
    elsif license.include?("/by-nc/")
      url = "https://i.creativecommons.org/l/by-nc/4.0/#{size}.png"
    else
      url = "/images/Clear1x1.gif"
    end
    url
  end

  def institution_codes
    occurrences.pluck(:institutionCode).compact.uniq.sort
  end

  def top_institution_codes
    codes = occurrences.pluck(:institutionCode)
               .inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}
    if codes.size < 5 && codes.values.sum > 10_000
        codes.sort_by{|k,v| v}
             .reverse
             .first(4)
             .to_h
             .keys rescue []
    else
      []
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

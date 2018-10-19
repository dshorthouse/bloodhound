class User < ActiveRecord::Base
  has_many :user_occurrences
  has_many :occurrences, through: :user_occurrences, source: :occurrence

  self.per_page = 25

  def is_public?
    is_public
  end

  def fullname
    if !family.blank?
      [given, family].compact.join(" ")
    else
      orcid
    end
  end

  def fullname_reverse
    if !family.blank?
      [family, given].compact.join(", ")
    else
      orcid
    end
  end

  def visible_occurrences
    occurrences.joins(:user_occurrences)
               .where(user_occurrences: { visible: true })
  end

  def visible_user_occurrences
    user_occurrences.where(visible: true)
  end

  def user_occurrence_occurrences
    visible_user_occurrences.map{|u| { user_occurrence_id: u.id, action: u.action }
                            .merge(u.occurrence.attributes.symbolize_keys) }
  end

  def user_occurrence_downloadable
    visible_user_occurrences.map{|u| { action: u.action }
                            .merge(u.occurrence.attributes.symbolize_keys) }
  end

  def identifications
    visible_occurrences.where(qry_identified)
  end

  def recordings
    visible_occurrences.where(qry_recorded)
  end

  def identified_families
    taxon_ids = visible_user_occurrences.where(qry_identified)
                                        .joins(:taxon_occurrence)
                                        .pluck(:taxon_id)
    Hash.new(0).tap{ |h| taxon_ids.each { |f| h[f] += 1 } }
               .transform_keys{ |key| Taxon.find(key).family }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def top_family_identified
    identified_families.first[0] if !identified_families.empty?
  end

  def recorded_families
    taxon_ids = visible_user_occurrences.where(qry_recorded)
                                        .joins(:taxon_occurrence)
                                        .pluck(:taxon_id)
    Hash.new(0).tap{ |h| taxon_ids.each { |f| h[f] += 1 } }
               .transform_keys{ |key| Taxon.find(key).family }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def top_family_recorded
    recorded_families.first[0] if !recorded_families.empty?
  end

  def identifications_recordings
    visible_occurrences.where(qry_identified_recorded)
  end

  def identified_count
    visible_user_occurrences.where(qry_identified)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def recorded_count
    visible_user_occurrences.where(qry_recorded)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def identified_and_recorded_count
    visible_user_occurrences.where(qry_identified_and_recorded)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def identified_or_recorded_count
    visible_user_occurrences.where(qry_identified_or_recorded)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def qry_identified
    "user_occurrences.action LIKE '%identified%'"
  end

  def qry_recorded
    "user_occurrences.action LIKE '%recorded%'"
  end

  def qry_identified_and_recorded
    "user_occurrences.action LIKE '%recorded%' AND user_occurrences.action LIKE '%identified%'"
  end

  def qry_identified_or_recorded
    "(user_occurrences.action LIKE '%recorded%' OR user_occurrences.action LIKE '%identified%')"
  end

end
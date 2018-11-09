class User < ActiveRecord::Base
  has_many :user_occurrences
  has_many :occurrences, -> { distinct }, through: :user_occurrences, source: :occurrence
  has_many :claims, foreign_key: :created_by, class_name: "UserOccurrence"
  has_many :claimed_occurrences, through: :claims, source: :occurrence

  before_update :set_update_time

  after_create :add_search
  after_update :update_search
  after_destroy :remove_search

  self.per_page = 25

  def is_public?
    is_public
  end

  def is_admin?
    is_admin
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

  def visible_user_occurrences
    user_occurrences.where(visible: true)
  end

  def visible_occurrences
    visible_user_occurrences.includes(:occurrence)
  end

  def hidden_occurrences
    hidden_user_occurrences.includes(:occurrence)
  end

  def hidden_user_occurrences
    user_occurrences.where(visible: false)
  end

  def claims_received_claimants
    claims_received.includes(:user_occurrence)
  end

  def identifications
    visible_occurrences.where(qry_identified)
  end

  def recordings
    visible_occurrences.where(qry_recorded)
  end

  def identifications_recordings
    visible_occurrences.where(qry_identified_recorded)
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
    taxon_ids = recordings.joins(:taxon_occurrence)
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

  def identified_count
    visible_user_occurrences.where(qry_identified).count
  end

  def recorded_count
    visible_user_occurrences.where(qry_recorded).count
  end

  def all_occurrences_count
    visible_user_occurrences.count
  end

  def identified_and_recorded_count
    visible_user_occurrences.where(qry_identified_and_recorded).count
  end

  def identified_or_recorded_count
    visible_user_occurrences.where(qry_identified_or_recorded).count
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

  def claims_given
    claims.where(visible: true).where.not(user: self)
  end

  def helped_count
    helped_ids.count
  end

  def helped_ids
    claims_given.pluck(:user_id).uniq
  end

  def helped_counts
    claims_given.group(:user_id).count.sort_by{|a,b| b}.reverse.to_h
  end

  def helped
    claims_given.map(&:user).uniq
  end

  def claims_received
    visible_occurrences.where.not(created_by: self)
  end

  def helped_by
    claims_received.map(&:user).uniq
  end

  def country_counts
    counts = recordings.pluck(:country)
                       .compact
                       .inject(Hash.new(0)) { |h, e| h[e] += 1 ; h }
    data = {}
    counts.each do |k,v|
      country = IsoCountryCodes.search_by_name(k) rescue nil
      if country && country.length > 0
        data[country.first.alpha2] = {name: country.first.name, count: v}
      end
    end
    data
  end

  def recorded_with
    User.includes(:user_occurrences)
        .where(user_occurrences: { occurrence_id: recordings.pluck(:occurrence_id) })
        .where.not(user_occurrences: { user_id: id })
        .uniq
  end

  def update_orcid_profile
    response = RestClient::Request.execute(
      method: :get,
      url: Sinatra::Application.settings.orcid_api_url + orcid,
      headers: { accept: 'application/orcid+json' }
    )
    data = JSON.parse(response, :symbolize_names => true)
    given = data[:person][:name][:"given-names"][:value] rescue nil
    family = data[:person][:name][:"family-name"][:value] rescue nil
    email = nil
    data[:person][:emails][:email].each do |mail|
      next if !mail[:primary]
      email = mail[:email]
    end
    other_names = data[:person][:"other-names"][:"other-name"].map{|n| n[:content]}.join("|") rescue nil
    country_code = data[:person][:addresses][:address][0][:country][:value] rescue nil
    country = IsoCountryCodes.find(country_code).name rescue nil
    update({
      family: family,
      given: given,
      email: email,
      other_names: other_names,
      country: country
    })
  end

  private

  def set_update_time
    self.updated = Time.now
  end

  def add_search
    if !self.family.blank?
      es = Bloodhound::ElasticIndexer.new
      es.add_user(self)
    end
  end

  def update_search
    if !self.family.blank?
      es = Bloodhound::ElasticIndexer.new
      if !es.get_user(self)
        es.add_user(self)
      else
        es.update_user(self)
      end
    end
  end

  def remove_search
    es = Bloodhound::ElasticIndexer.new
    es.delete_user(self)
  end

end
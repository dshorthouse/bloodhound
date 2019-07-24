class User < ActiveRecord::Base
  serialize :zenodo_access_token, Hash

  has_many :user_occurrences, dependent: :delete_all
  has_many :occurrences, -> { distinct }, through: :user_occurrences, source: :occurrence
  has_many :claims, foreign_key: :created_by, class_name: "UserOccurrence", dependent: :delete_all
  has_many :claimed_occurrences, through: :claims, source: :occurrence
  has_many :user_organizations, dependent: :delete_all
  has_many :organizations, through: :user_organizations, source: :organization

  before_update :set_update_time
  after_create :update_profile, :add_search
  after_update :update_search
  after_destroy :remove_search, :create_destroyed_user

  def is_public?
    is_public
  end

  def is_admin?
    is_admin
  end

  def can_comment?
    can_comment
  end

  def made_claim?
    visible_user_occurrences.count > 0
  end

  def wants_mail?
    wants_mail
  end

  def identifier
    orcid || wikidata
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

  def complete_wikicontent?
    !family.nil? && !date_born.nil? && !date_died.nil?
  end

  def visible_user_occurrences
    user_occurrences.where(visible: true)
  end

  def visible_occurrences
    visible_user_occurrences.includes(:occurrence)
  end

  def hidden_occurrences
    hidden_user_occurrences.includes(:occurrence).order(created: :desc)
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
    visible_occurrences.where.not(created_by: self).order(created: :desc)
  end

  def helped_by
    claims_received.map(&:claimant).uniq
  end

  def country_counts
    counts = recordings.pluck(:countryCode)
                       .compact
                       .inject(Hash.new(0)) { |h, e| h[e] += 1 ; h }
    data = {}
    counts.each do |k,v|
      country = IsoCountryCodes.find(k) rescue nil
      if country
        data[country.alpha2] = { name: country.name, count: v }
      end
    end
    data
  end

  def quick_country_counts
    visible_user_occurrences.joins(:occurrence).where(qry_recorded).select(:countryCode).distinct.count
  end

  def recorded_with
    User.joins("JOIN user_occurrences as a ON a.user_id = users.id JOIN user_occurrences b ON a.occurrence_id = b.occurrence_id")
        .where("b.user_id = #{id}")
        .where("b.action LIKE '%recorded%'")
        .where("b.visible = true")
        .where("a.user_id != #{id}")
        .where("a.action LIKE '%recorded%'")
        .where("a.visible = true")
        .distinct
        .order(:family)
  end

  def identified_for
    User.joins("JOIN user_occurrences as a ON a.user_id = users.id JOIN user_occurrences b ON a.occurrence_id = b.occurrence_id")
        .where("b.user_id = #{id}")
        .where("b.action LIKE '%identified%'")
        .where("b.visible = true")
        .where("a.user_id != #{id}")
        .where("a.action LIKE '%recorded%'")
        .where("a.visible = true")
        .distinct
        .order(:family)
  end

  def identified_by
    User.joins("JOIN user_occurrences as a ON a.user_id = users.id JOIN user_occurrences b ON a.occurrence_id = b.occurrence_id")
        .where("b.user_id = #{id}")
        .where("b.action LIKE '%recorded%'")
        .where("b.visible = true")
        .where("a.user_id != #{id}")
        .where("a.action LIKE '%identified%'")
        .where("a.visible = true")
        .distinct
        .order(:family)
  end

  def recordings_deposited_at
    codes = recordings.pluck(:institutionCode).compact
    Hash.new(0).tap{ |h| codes.each { |f| h[f] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def identifications_deposited_at
    codes = identifications.pluck(:institutionCode).compact
    Hash.new(0).tap{ |h| codes.each { |f| h[f] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def current_organization
    current = user_organizations.where.not(start_year: nil)
                                .where(end_year: nil)
                                .first
                                .organization rescue nil
    if current.nil?
      current = user_organizations.where(end_year: nil)
                                  .first
                                  .organization rescue nil
    end
    current
  end

  def update_profile
    if wikidata
      update_wikidata_profile
    elsif orcid
      update_orcid_profile
    end
  end

  def update_orcid_profile
    UserOrganization.where(user_id: id).destroy_all

    orcid_lib = Bloodhound::OrcidSearch.new
    data = orcid_lib.account_data(orcid)
    data[:organizations].each do |org|
      update_affiliation(org)
    end

    update(data.except!(:organizations))
  end

  def update_wikidata_profile
    wikidata_lib = Bloodhound::WikidataSearch.new
    data = wikidata_lib.wiki_user_data(wikidata)
    data[:organizations].each do |org|
      update_affiliation(org)
    end
    update(data.except!(:organizations))
  end

  def update_affiliation(org)
    next if org[:wikidata].nil? && org[:grid].nil? && org[:ringgold].nil?
    if !org[:grid].nil?
      organization = Organization.find_by_grid(org[:grid])
    elsif !org[:ringgold].nil?
      organization = Organization.find_by_ringgold(org[:ringgold].to_i)
    elsif !org[:wikidata].nil?
      organization = Organization.find_by_wikidata(org[:wikidata])
    end

    if organization.nil?
      organization = Organization.create(
                       ringgold: org[:ringgold],
                       grid: org[:grid],
                       name: org[:name],
                       address: org[:address]
                     )
    end
    UserOrganization.create({
      user_id: id,
      organization_id: organization.id,
      start_year: org[:start_year],
      start_month: org[:start_month],
      start_day: org[:start_day],
      end_year: org[:end_year],
      end_month: org[:end_month],
      end_day: org[:end_day]
    })
  end

  def articles_citing_specimens
    subq = Article.joins(article_occurrences: :user_occurrences)
                  .where(user_occurrences: { user_id: id, visible: true })
                  .distinct
    Article.select('*').from(subq).order(created: :desc)
  end

  def cited_specimens
    visible_occurrences.joins(:article_occurrences)
  end

  def cited_specimens_by_article(article_id)
    cited_specimens.where(article_occurrences: { article_id: article_id })
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
    begin
      es.delete_user(self)
    rescue
    end
  end

  def create_destroyed_user
    DestroyedUser.find_or_create_by({ identifier: self.identifier })
  end

end

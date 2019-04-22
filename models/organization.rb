class Organization < ActiveRecord::Base
  serialize :institution_codes, Array

  has_many :user_organizations
  has_many :users, through: :user_organizations, source: :user

  after_create :add_search

  def self.active_user_organizations
    self.includes(:user_organizations)
        .where(user_organizations: { end_year: nil })
        .distinct
  end

  def self.find_by_identifier(id)
    self.find_by_wikidata(id) || self.find_by_ringgold(id) || self.find_by_grid(id)
  end

  def identifier
    wikidata || grid || ringgold
  end

  def active_users
    users.includes(:user_organizations)
         .where(user_organizations: { end_year: nil })
         .distinct
  end

  def inactive_users
    users.includes(:user_organizations)
         .where.not(user_organizations: { end_year: nil })
         .distinct
  end

  def public_users
    users.includes(:user_organizations)
         .where(user_organizations: { end_year: nil })
         .where(is_public: true).distinct
  end

  def active_users_own_specimens_recorded
    UserOccurrence.joins("JOIN occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%recorded%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NULL")
                  .where("YEAR(occurrences.eventDate_processed) >= uo.start_year")
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode IN (?)", institution_codes)
                  .pluck("user_occurrences.occurrence_id").uniq
  end

  def active_users_own_specimens_identified
    UserOccurrence.joins("JOIN occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%identified%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NULL")
                  .where("YEAR(occurrences.dateIdentified_processed) >= uo.start_year")
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode IN (?)", institution_codes)
                  .pluck("user_occurrences.occurrence_id").uniq
  end

  def users_others_specimens_recorded
    current = Occurrence.joins("JOIN user_occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%recorded%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NULL")
                  .where("YEAR(occurrences.eventDate_processed) >= uo.start_year")
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode NOT IN (?)", institution_codes)
    past = Occurrence.joins("JOIN user_occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%recorded%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NOT NULL")
                  .where("uo.start_year IS NOT NULL")
                  .where("YEAR(occurrences.eventDate_processed) >= uo.start_year")
                  .where("YEAR(occurrences.eventDate_processed) <= uo.end_year")
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode NOT IN (?)", institution_codes)
    combined = current.union_all(past)
                      .distinct
                      .unscope(:order)
                      .pluck(:gbifID, :institutionCode).compact
    Hash.new(0).tap{ |h| combined.each { |f| h[f[1]] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def users_others_specimens_identified
    current = Occurrence.joins("JOIN user_occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%identified%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NULL")
                  .where("YEAR(occurrences.dateIdentified_processed) >= uo.start_year")
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode NOT IN (?)", institution_codes)
    past = Occurrence.joins("JOIN user_occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%identified%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NOT NULL")
                  .where("uo.start_year IS NOT NULL")
                  .where("YEAR(occurrences.dateIdentified_processed) >= uo.start_year")
                  .where("YEAR(occurrences.dateIdentified_processed) <= uo.end_year")
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode NOT IN (?)", institution_codes)
    combined = current.union_all(past)
                      .distinct
                      .unscope(:order)
                      .pluck(:gbifID, :institutionCode).compact
    Hash.new(0).tap{ |h| combined.each { |f| h[f[1]] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def users_others_specimens_identified_year(year)
    current = Occurrence.joins("JOIN user_occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%identified%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NULL")
                  .where("uo.start_year <= ?", year)
                  .where("YEAR(occurrences.dateIdentified_processed) = ?", year)
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode NOT IN (?)", institution_codes)
    past = Occurrence.joins("JOIN user_occurrences ON user_occurrences.occurrence_id = occurrences.gbifID JOIN users u ON u.id = user_occurrences.user_id JOIN user_organizations uo ON uo.user_id = u.id")
                  .where("user_occurrences.visible = 1")
                  .where("user_occurrences.action LIKE '%identified%'")
                  .where("uo.organization_id = ?", id)
                  .where("uo.end_year IS NOT NULL")
                  .where("uo.start_year IS NOT NULL")
                  .where("uo.start_year >= ?", year)
                  .where("uo.end_year <= ?", year)
                  .where("YEAR(occurrences.dateIdentified_processed) = ?", year)
                  .where("occurrences.institutionCode IS NOT NULL")
                  .where("occurrences.institutionCode NOT IN (?)", institution_codes)
    combined = current.union_all(past)
                      .distinct
                      .unscope(:order)
                      .pluck(:gbifID, :institutionCode).compact

    Hash.new(0).tap{ |h| combined.each { |f| h[f[1]] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def update_isni
    base_url = "https://orcid.org/orgs/disambiguated/"
    if !ringgold.nil?
      path = "RINGGOLD?value=#{ringgold}"
    elsif !grid.nil?
      path = "GRID?value=#{grid}"
    end
    response = RestClient::Request.execute(
      method: :get,
      url: "#{base_url}#{path}",
      headers: { accept: 'application/json' }
    )
    isni = nil
    begin
      data = JSON.parse(response, :symbolize_names => true)
      data[:orgDisambiguatedExternalIdentifiers].each do |ids|
        next if ids[:identifierType] != "ISNI"
        isni = ids[:all][0].delete(' ')
        self.isni = isni
        save
      end
    rescue
    end
    isni
  end

  def update_institution_codes
    wikidata_lib = Bloodhound::WikidataSearch.new
    codes = wikidata_lib.wiki_institution_codes(identifier)
    update(codes) if !codes[:institution_codes].empty?
  end

  def update_wikidata
    wikidata_lib = Bloodhound::WikidataSearch.new
    code = wikidata || identifier.to_s
    wiki = wikidata_lib.institution_wikidata(code)
    update(wiki) if !wiki[:wikidata].nil?
  end

  private

  def add_search
    es = Bloodhound::ElasticIndexer.new
    if !es.get_organization(self)
      es.add_organization(self)
    end
  end

end

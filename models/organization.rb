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
    self.find_by_ringgold(id) || self.find_by_grid(id)
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

  def identifier
    ringgold || grid
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
    update({ institution_codes: codes})
  end

  private

  def add_search
    es = Bloodhound::ElasticIndexer.new
    if !es.get_organization(self)
      es.add_organization(self)
    end
  end

end

class Organization < ActiveRecord::Base
  has_many :user_organizations
  has_many :users, through: :user_organizations, source: :user

  self.per_page = 30

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

  private

  def add_search
    es = Bloodhound::ElasticIndexer.new
    if !es.get_organization(self)
      es.add_organization(self)
    end
  end

end
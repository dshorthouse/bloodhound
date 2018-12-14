class Organization < ActiveRecord::Base
  has_many :user_organizations
  has_many :users, through: :user_organizations, source: :user

  self.per_page = 30

  def self.active_user_organizations
    self.includes(:user_organizations, :users)
        .where(user_organizations: { end_year: nil })
        .where(users: { is_public: true })
  end

  def public_users
    users.includes(:user_organizations)
         .where(user_organizations: { end_year: nil })
         .where(is_public: true).distinct
  end

  def identifier
    ringgold || grid
  end

end
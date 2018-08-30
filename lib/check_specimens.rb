# encoding: utf-8

module Bloodhound
  module CheckSpecimens

    def self.all
      User.find_each do |user|
        user.check_changes
      end
    end

    def self.user(orcid)
      user = User.find_by_orcid(orcid)
      user.check_changes
    end

  end
end
# encoding: utf-8

module Bloodhound
  class SitemapGenerator

    def initialize(args = {})
      args = defaults.merge(args)
      @domain = args[:domain]
      @directory = args[:directory]
      @map = XmlSitemap::Map.new(@domain, { secure: true })
    end

    def add_flat_pages
      @map.add '/about'
      @map.add '/agents'
      @map.add '/countries'
      @map.add '/datasets'
      @map.add '/donate'
      @map.add '/get-started'
      @map.add '/developers'
      @map.add '/how-it-works'
      @map.add '/integrations'
      @map.add '/organizations'
      @map.add '/roster'
      @map.add '/trainers'
    end

    def add_users
      User.where(is_public: true).find_each do |user|
        @map.add "/#{user.identifier}"
        @map.add "/#{user.identifier}/specialties"
        @map.add "/#{user.identifier}/co-collectors"
        @map.add "/#{user.identifier}/identified-for"
        @map.add "/#{user.identifier}/identifications-by"
        @map.add "/#{user.identifier}/deposited-at"
        @map.add "/#{user.identifier}/citations"
        @map.add "/#{user.identifier}/specimens"
        @map.add "/#{user.identifier}/comments"
      end
    end

    def add_organizations
      Organization.find_each do |o|
        @map.add "/organization/#{o.identifier}"
        @map.add "/organization/#{o.identifier}/past"
        @map.add "/organization/#{o.identifier}/metrics"
        @map.add "/organization/#{o.identifier}/citations"
      end
    end

    def add_countries
      countries = IsoCountryCodes.for_select
      countries.each do |country|
        @map.add "/country/#{country[1]}"
      end
    end

    def add_datasets
      Dataset.find_each do |d|
        @map.add "/dataset/#{d.datasetKey}"
      end
    end

    def render
      @map.render_to(File.join(@directory, "sitemap.xml.gz"), gzip: true)
    end

    private

    def defaults
      { domain: "example.com", directory: "/tmp" }
    end

  end
end
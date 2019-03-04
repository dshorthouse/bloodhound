# encoding: utf-8

module Bloodhound
  class SitemapGenerator

    def initialize(args = {})
      args = defaults.merge(args)
      @domain = args[:domain]
      @directory = args[:directory]
      @map = XmlSitemap::Map.new(@domain)
    end

    def add_flat_pages
      @map.add '/about'
      @map.add '/agents'
      @map.add '/get-started'
      @map.add '/integrations'
      @map.add '/organizations'
      @map.add '/roster'
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

    def render
      @map.render_to(File.join(@directory, "sitemap.xml.gz"), gzip: true)
    end

    private

    def defaults
      { domain: "example.com", directory: "/tmp" }
    end

  end
end
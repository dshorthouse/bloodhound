# encoding: utf-8

module Bloodhound
  class OrcidSearch

    def initialize
      @settings = Sinatra::Application.settings
    end

    def populate_new_users(doi = nil)
      found_orcids = !doi.nil? ? search_orcids_by_doi(doi) : search_orcids_by_keyword
      (found_orcids.to_a - existing_orcids).each do |orcid|
        create_user(orcid)
      end
    end

    def search_orcids_by_doi(doi)
      lucene_chars = {
        '+' => '\+',
        '-' => '\-',
        '&' => '\&',
        '|' => '\|',
        '!' => '\!',
        '(' => '\(',
        ')' => '\)',
        '{' => '\{',
        '}' => '\}',
        '[' => '\[',
        ']' => '\]',
        '^' => '\^',
        '"' => '\"',
        '~' => '\~',
        '*' => '\*',
        '?' => '\?',
        ':' => '\:'
      }
      clean_doi = URI::encode(doi.gsub(/[#{lucene_chars.keys.join('\\')}]/, lucene_chars))

      Enumerator.new do |yielder|
        start = 0
        loop do
          orcid_search_url = "#{@settings.orcid_api_url}search?q=doi-self:#{clean_doi}&start=#{start}&rows=50"
          response = RestClient::Request.execute(
            method: :get,
            url: orcid_search_url,
            headers: { accept: 'application/orcid+json' }
          )
          results = JSON.parse(response, :symbolize_names => true)[:result] rescue []
          if results.size > 0
            results.map { |item| yielder << item[:"orcid-identifier"][:path] }
            start += 50
          else
            raise StopIteration
          end
        end
      end.lazy
    end

    def search_orcids_by_keyword
      if !@settings.orcid_keywords || !@settings.orcid_keywords.is_a?(Array)
        raise ArgumentError, 'ORCID keywords to search on not in config.yml' 
      end

      keyword_parameter = URI::encode(@settings.orcid_keywords.map{ |k| "keyword:#{k}" }.join(" OR "))
      Enumerator.new do |yielder|
        start = 0

        loop do
          orcid_search_url = "#{@settings.orcid_api_url}search?q=#{keyword_parameter}&start=#{start}&rows=200"
          response = RestClient::Request.execute(
            method: :get,
            url: orcid_search_url,
            headers: { accept: 'application/orcid+json' }
          )
          results = JSON.parse(response, :symbolize_names => true)[:result] rescue []
          if results.size > 0
            results.map { |item| yielder << item[:"orcid-identifier"][:path] }
            start += 200
          else
            raise StopIteration
          end
        end
      end.lazy
    end

    def existing_orcids
      User.pluck(:orcid)
    end

    def create_user(orcid)
      u = User.create(orcid: orcid)
      u.update_orcid_profile
      puts "#{u.fullname_reverse}".green
    end

  end
end
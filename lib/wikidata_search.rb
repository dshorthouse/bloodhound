# encoding: utf-8

module Bloodhound
  class WikidataSearch

    WIKIDATA_PROPERTIES = {
      "IPNI": "P586",
      "Entomologists of the World": "P5370"
    }

    def initialize
      @settings = Sinatra::Application.settings
      @sparql = SPARQL::Client.new("https://query.wikidata.org/sparql")
    end

    def wikidata_query(property)
      %Q(
          SELECT
            ?item
          WHERE {
            ?item wdt:#{property} ?id.
            SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
            OPTIONAL { ?item p:P569/psv:P569 [wikibase:timePrecision ?birth_precision; wikibase:timeValue ?birth]
            BIND(if(?birth_precision=11,?birth,if(?birth_precision=10,concat(month(?birth)," ",year(?birth)),year(?birth))) as ?date_of_birth) }
            OPTIONAL { ?item p:P570/psv:P570 [wikibase:timePrecision ?death_precision; wikibase:timeValue ?death]
            BIND(if(?death_precision=11,?death,if(?death_precision=10,concat(month(?death)," ",year(?death)),year(?death))) as ?date_of_death) }
            FILTER(?birth_precision=11 && ?death_precision=11 )
          }
        )
    end

    def found_wikicodes
      codes = []
      WIKIDATA_PROPERTIES.values.each do |code|
        @sparql.query(wikidata_query(code)).each_solution do |solution|
          codes << solution.to_h[:item].to_s.match(/Q[0-9]{1,}/).to_s
        end
      end
      codes
    end

    def populate_new_users
      (found_wikicodes - existing_wikicodes).each do |wikidata|
        create_user(wikidata)
      end
    end

    def account_data(wikicode)
      wiki_user = Wikidata::Item.find(wikicode)
      parsed = Namae.parse(wiki_user.title)[0] rescue nil
      family = parsed.family rescue nil
      given = parsed.given rescue nil
      country = wiki_user.properties("P27").compact.map(&:title).join("|") rescue nil
      country_code = wiki_user.properties("P27").compact.map{|a| find_country_code(a.title) }.compact.join("|") rescue nil
      keywords = wiki_user.properties("P106").compact.map(&:title).join("|") rescue nil
      other_names = wiki_user.aliases.values.compact.map{|a| a.map{|b| b.value if b.language == "en"}.compact}.flatten.uniq.join("|") rescue nil
      date_born = Date.parse(wiki_user.properties("P569").compact.map{|a| a.value.time if a.precision_key == :day}.compact.first) rescue nil
      date_died = Date.parse(wiki_user.properties("P570").compact.map{|a| a.value.time if a.precision_key == :day}.compact.first) rescue nil
      {
        family: family,
        given: given,
        other_names: other_names,
        country: country,
        country_code: country_code,
        keywords: keywords,
        date_born: date_born,
        date_died: date_died
      }
    end

    def existing_wikicodes
      User.pluck(:wikidata)
    end

    def create_user(wikidata)
      u = User.create(wikidata: wikidata)
      u.update_wikidata_profile
      puts "#{u.fullname_reverse}".green
    end

    def find_country_code(name)
      begin
        IsoCountryCodes.search_by_name(name).first.alpha2
      rescue
        nil
      end
    end

  end
end
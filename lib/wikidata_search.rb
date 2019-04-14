# encoding: utf-8

module Bloodhound
  class WikidataSearch

    PEOPLE_PROPERTIES = {
      "IPNI": "P586",
      "Harvard Index of Botanists": "P6264",
      "Entomologists of the World": "P5370",
      "BHL Creator ID": "P4081"
    }

    def initialize
      @settings = Sinatra::Application.settings
      @sparql = SPARQL::Client.new("https://query.wikidata.org/sparql")
    end

    def wikidata_people_query
      properties_list = PEOPLE_PROPERTIES.values.map{|a| "wdt:#{a}"}.join("|")
      %Q(
          SELECT DISTINCT
            ?item ?itemLabel
          WHERE {
            ?item #{properties_list} ?id.
            SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
            OPTIONAL { ?item p:P569/psv:P569 [wikibase:timePrecision ?birth_precision; wikibase:timeValue ?birth]
            BIND(if(?birth_precision=11,?birth,if(?birth_precision=10,concat(month(?birth)," ",year(?birth)),year(?birth))) as ?date_of_birth) }
            OPTIONAL { ?item p:P570/psv:P570 [wikibase:timePrecision ?death_precision; wikibase:timeValue ?death]
            BIND(if(?death_precision=11,?death,if(?death_precision=10,concat(month(?death)," ",year(?death)),year(?death))) as ?date_of_death) }
            FILTER(?birth_precision=11 && ?death_precision=11 )
          }
        )
    end

    # With help from @rdmpage
    def wikidata_institution_code_query(identifier)
      %Q(
        SELECT DISTINCT
          *
        WHERE {
          VALUES ?identifier {"#{identifier}"} {
            # institution that includes collection has grid or ringgold
            ?institution wdt:P3500|wdt:P2427 ?identifier .
            # various part of relationships
            ?collection wdt:P195|wdt:P137|wdt:P749|wdt:P361 ?institution .
          } UNION {
            # collection itself has grid or ringgold
            ?collection wdt:P3500|wdt:P2427 ?identifier .
          }
          # Code(s) for collection
          {
            # Index Herb. or Biodiv Repo ID
            ?collection wdt:P5858|wdt:P4090 ?code .
          } UNION {
            # Derive from Wikispecies URL
            ?wikispecies schema:about ?collection .
            BIND( REPLACE( STR(?wikispecies),"https://species.wikimedia.org/wiki/","" ) AS ?code).
            FILTER contains (STR(?wikispecies),'species.wikimedia.org')
          }
        }
      )
    end

    def wikidata_institution_wiki_query(identifier)
      %Q(
        SELECT ?item ?lat ?long ?image_url ?website
        WHERE {
          ?item wdt:P3500|wdt:P2427 '#{identifier}' .
          ?item p:P625 ?statement .
          ?statement psv:P625 ?coordinate_node .
          ?coordinate_node wikibase:geoLatitude ?lat .
          ?coordinate_node wikibase:geoLongitude ?long .
          ?item wdt:P18 ?image_url .
          ?item wdt:P856 ?website .
          SERVICE wikibase:label {
            bd:serviceParam wikibase:language "en" .
          }
        }
      )
    end

    def populate_new_users
      existing = existing_wikicodes
      @sparql.query(wikidata_people_query).each_solution do |solution|
        wikicode = solution.to_h[:item].to_s.match(/Q[0-9]{1,}/).to_s
        next if existing.include? wikicode

        name = solution.to_h[:itemLabel].to_s
        parsed = Namae.parse(name)[0] rescue nil
        next if parsed.nil? || parsed[:family].nil? || parsed[:given].nil?

        u = User.create({ wikidata: wikicode })
        puts u.fullname_reverse.green
      end
    end

    def wiki_institution_codes(identifier)
      institution_codes = []
      @sparql.query(wikidata_institution_code_query(identifier)).each_solution do |solution|
        institution_codes << solution.code.to_s
      end
      institution_codes.uniq
    end

    def institution_wikidata(identifier)
      wikidata = {}
      response = @sparql.query(wikidata_institution_wiki_query(identifier)).first
      if response
        wikicode = response[:item].to_s.match(/Q[0-9]{1,}/).to_s
        latitude = response[:lat].to_f
        longitude = response[:long].to_f
        image_url = response[:image_url].to_s
        website = response[:website].to_s
        wikidata = {
          wikidata: wikicode,
          latitude: latitude,
          longitude: longitude,
          image_url: image_url,
          website: website
        }
      end
      wikidata
    end

    def wiki_user_data(wikicode)
      wiki_user = Wikidata::Item.find(wikicode)
      parsed = Namae.parse(wiki_user.title)[0] rescue nil
      family = parsed.family rescue nil
      given = parsed.given rescue nil
      country = wiki_user.properties("P27").compact.map(&:title).join("|") rescue nil
      country_code = wiki_user.properties("P27").compact.map{|a| find_country_code(a.title) }.compact.join("|") rescue nil
      keywords = wiki_user.properties("P106").compact.map(&:title).join("|") rescue nil
      image_url = nil
      image = wiki_user.image.value rescue nil
      if image
        image_url = "http://commons.wikimedia.org/wiki/Special:FilePath/" << URI.encode(wiki_user.image.value)
      end
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
        image_url: image_url,
        date_born: date_born,
        date_died: date_died
      }
    end

    def existing_wikicodes
      User.pluck(:wikidata)
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

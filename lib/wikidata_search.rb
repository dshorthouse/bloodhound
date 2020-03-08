# encoding: utf-8

module Bloodhound
  class WikidataSearch

    PEOPLE_PROPERTIES = {
      "IPNI": "P586",
      "Harvard Index of Botanists": "P6264",
      "Entomologists of the World": "P5370",
      "ZooBank Author ID": "P2006",
      "BHL Creator ID": "P4081",
      "Stuttgart Database of Scientific Illustrators ID": "P2349"
    }

    def initialize
      headers = { 'User-Agent' => 'Bloodhound/1.0' }
      @sparql = SPARQL::Client.new("https://query.wikidata.org/sparql", headers: headers, read_timeout: 120)
    end

    def wikidata_people_query(property)
      one_week_ago = Time.now - 604800
      %Q(
          SELECT DISTINCT
            ?item ?itemLabel
          WHERE {
            ?item wdt:#{property} ?id .
            ?item schema:dateModified ?change .
            SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
            OPTIONAL { ?item p:P569/psv:P569 [wikibase:timePrecision ?birth_precision; wikibase:timeValue ?birth]
            BIND(if(?birth_precision=11,?birth,if(?birth_precision=10,concat(month(?birth)," ",year(?birth)),year(?birth))) as ?date_of_birth) }
            OPTIONAL { ?item p:P570/psv:P570 [wikibase:timePrecision ?death_precision; wikibase:timeValue ?death]
            BIND(if(?death_precision=11,?death,if(?death_precision=10,concat(month(?death)," ",year(?death)),year(?death))) as ?date_of_death) }
            FILTER(?birth_precision=11 && ?death_precision=11 && ?change > "#{one_week_ago.iso8601}"^^xsd:dateTime)
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
          VALUES ?identifier {"#{identifier}"} {
            ?item wdt:P3500|wdt:P2427 ?identifier .
          }
          OPTIONAL {
            ?item p:P625 ?statement .
            ?statement psv:P625 ?coordinate_node .
            ?coordinate_node wikibase:geoLatitude ?lat .
            ?coordinate_node wikibase:geoLongitude ?long .
          }
          OPTIONAL {
            ?item wdt:P18|wdt:P154 ?image_url .
          }
          OPTIONAL {
            #TODO FILTER BY current when a date
            ?item wdt:P856 ?website .
          }
          SERVICE wikibase:label {
            bd:serviceParam wikibase:language "en" .
          }
        }
      )
    end

    def wikidata_by_orcid_query(orcid)
      %Q(
        SELECT ?item ?itemLabel ?twitter
        WHERE {
          VALUES ?orcid {"#{orcid}"} {
            ?item wdt:P496 ?orcid .
          }
          OPTIONAL {
            ?item wdt:P2002 ?twitter .
          }
          SERVICE wikibase:label {
            bd:serviceParam wikibase:language "en" .
          }
        }
      )
    end

    def merged_wikidata_people_query(property)
      %Q(
        SELECT (REPLACE(STR(?item),".*Q","Q") AS ?qid) (REPLACE(STR(?redirect),".*Q","Q") AS ?redirect_toqid)
        WHERE {
          ?redirect wdt:P31 wd:Q5 .
          ?redirect wdt:#{property} ?id .
          ?item owl:sameAs ?redirect .
          SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en" }
          OPTIONAL { ?redirect p:P569/psv:P569 [wikibase:timePrecision ?birth_precision; wikibase:timeValue ?birth]
          BIND(if(?birth_precision=11,?birth,if(?birth_precision=10,concat(month(?birth)," ",year(?birth)),year(?birth))) as ?date_of_birth) }
          OPTIONAL { ?redirect p:P570/psv:P570 [wikibase:timePrecision ?death_precision; wikibase:timeValue ?death]
          BIND(if(?death_precision=11,?death,if(?death_precision=10,concat(month(?death)," ",year(?death)),year(?death))) as ?date_of_death) }
          FILTER(?birth_precision=11 && ?death_precision=11 )
        }
      )
    end

    def wikidata_modified_query(property)
      yesterday = Time.now - 86400
      %Q(
        SELECT (REPLACE(STR(?item),".*Q","Q") AS ?qid)
        WHERE {
          ?item wdt:P31 wd:Q5 .
          ?item wdt:#{property} ?id .
          ?item schema:dateModified ?change .
          SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en" }
          OPTIONAL { ?item p:P569/psv:P569 [wikibase:timePrecision ?birth_precision; wikibase:timeValue ?birth]
          BIND(if(?birth_precision=11,?birth,if(?birth_precision=10,concat(month(?birth)," ",year(?birth)),year(?birth))) as ?date_of_birth) }
          OPTIONAL { ?item p:P570/psv:P570 [wikibase:timePrecision ?death_precision; wikibase:timeValue ?death]
          BIND(if(?death_precision=11,?death,if(?death_precision=10,concat(month(?death)," ",year(?death)),year(?death))) as ?date_of_death) }
          FILTER(?birth_precision=11 && ?death_precision=11 && ?change > "#{yesterday.iso8601}"^^xsd:dateTime)
        }
      )
    end

    def populate_new_users
      existing = existing_wikicodes + destroyed_users
      new_wikicodes = {}
      PEOPLE_PROPERTIES.each do |key,property|
        puts "Polling #{key}...".yellow
        @sparql.query(wikidata_people_query(property)).each_solution do |solution|
          wikicode = solution.to_h[:item].to_s.match(/Q[0-9]{1,}/).to_s
          next if existing.include? wikicode
          new_wikicodes[wikicode] = solution.to_h[:itemLabel].to_s
        end
      end

      new_wikicodes.each do |wikicode, name|
        parsed = DwcAgent.parse(name)[0] rescue nil
        next if parsed.nil? || parsed.family.nil? || parsed.given.nil?

        u = User.find_or_create_by({ wikidata: wikicode })
        if !u.valid_wikicontent?
          u.delete
          puts "#{u.wikidata} deleted. Missing either family name, birth or death date".red
        else
          puts "#{u.fullname_reverse}".green
        end
      end
    end

    def recently_modified
      requires_refresh = []
      PEOPLE_PROPERTIES.each do |key,property|
        puts "Updates for #{key}...".yellow
        @sparql.query(wikidata_modified_query(property)).each_solution do |solution|
          requires_refresh << solution.to_h[:qid].to_s.match(/Q[0-9]{1,}/).to_s
        end
      end
      requires_refresh.uniq
    end

    def merge_users
      merged_wikicodes = {}
      PEOPLE_PROPERTIES.each do |key,property|
        puts "Merges for #{key}...".yellow
        @sparql.query(merged_wikidata_people_query(property)).each_solution do |solution|
          qid = solution.to_h[:qid].to_s.match(/Q[0-9]{1,}/).to_s
          merged_wikicodes[qid] =  solution.to_h[:redirect_toqid].to_s.match(/Q[0-9]{1,}/).to_s
        end
      end
      qids_to_merge = merged_wikicodes.keys & existing_wikicodes
      qids_to_merge.each do |qid|
        dest_qid = merged_wikicodes[qid]
        DestroyedUser.create(identifier: qid, redirect_to: dest_qid)

        src = User.find_by_wikidata(qid)
        dest = User.find_by_wikidata(dest_qid)
        if dest.nil?
          src.wikidata = dest_qid
          src.save
          src.reload
          src.update_wikidata_profile
        else
          occurrences = src.user_occurrences
          dest.user_occurrences.pluck(:occurrence_id).in_groups_of(500, false) do |group|
            occurrences.where.not(occurrence_id: group).update_all({ user_id: dest.id })
          end
          if src.is_public?
            dest.is_public = true
            dest.save
          end
          dest.update_wikidata_profile
          src.destroy
        end
        puts "#{qid} => #{dest_qid}".red
      end
    end

    def wiki_institution_codes(identifier)
      institution_codes = []
      @sparql.query(wikidata_institution_code_query(identifier)).each_solution do |solution|
        institution_codes << solution.code.to_s
      end
      { institution_codes: institution_codes.uniq }
    end

    def institution_wikidata(identifier)
      wikicode, latitude, longitude, image_url, logo_url, website = nil

      if identifier.match(/Q[0-9]{1,}/)
        data = Wikidata::Item.find(identifier)
        wikicode = identifier
        latitude = data.properties("P625").first.latitude.to_f rescue nil
        longitude = data.properties("P625").first.longitude.to_f rescue nil
        image = data.properties("P18").first.url rescue nil
        logo = data.properties("P154").first.url rescue nil
        image_url = image || logo
        website = data.properties("P856").last.value rescue nil
      else
        response = @sparql.query(wikidata_institution_wiki_query(identifier)).first
        if response
          wikicode = response[:item].to_s.match(/Q[0-9]{1,}/).to_s
          latitude = response[:lat].to_f if !response[:lat].nil?
          longitude = response[:long].to_f if !response[:long].nil?
          image_url = response[:image_url].to_s if !response[:image_url].nil?
          website = response[:website].to_s if !response[:website].nil?
        end
      end
      {
        wikidata: wikicode,
        latitude: latitude,
        longitude: longitude,
        image_url: image_url,
        website: website
      }
    end

    def parse_wikitime(time, precision)
      year = nil
      month = nil
      day = nil
      d = Hash[[:year, :month, :day, :hour, :min, :sec].zip(
        time.scan(/(-?\d+)-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/)
            .first
            .map(&:to_i)
      )]
      if precision > 8
        year = d[:year]
      end
      if precision > 9
        month = d[:month]
      end
      if precision > 10
        day = d[:day]
      end
      { year: year, month: month, day: day }
    end

    def wiki_user_data(wikicode)
      wiki_user = Wikidata::Item.find(wikicode)

      if !wiki_user ||
          wiki_user.properties("P31").size == 0 ||
         !wiki_user.properties("P31")[0].respond_to?("title") ||
          wiki_user.properties("P31")[0].title != "human"
        return
      end

      parsed = DwcAgent.parse(wiki_user.title)[0] rescue nil

      family = parsed.family rescue nil
      given = parsed.given rescue nil

      if family.nil? && !given.nil?
        family = given.dup
        given = ""
      end

      particle = parsed.particle rescue nil
      country = wiki_user.properties("P27")
                         .compact
                         .map(&:title)
                         .join("|") rescue nil
      country_code = wiki_user.properties("P27")
                              .compact
                              .map{|a| find_country_code(a.title) || "" }
                              .compact
                              .join("|")
                              .presence rescue nil
      keywords = wiki_user.properties("P106")
                          .map{|k| k.title if !/^Q\d+/.match?(k.title)}
                          .compact
                          .join("|") rescue nil
      orcid = wiki_user.properties("P496")
                       .first
                       .value rescue nil

      image_url = nil
      signature_url = nil
      image = wiki_user.image.value rescue nil
      if image
        image_url = "https://commons.wikimedia.org/wiki/Special:FilePath/" << URI.encode(image)
      end
      signature = wiki_user.properties("P109").first.value rescue nil
      if signature
        signature_url = "https://commons.wikimedia.org/wiki/Special:FilePath/" << URI.encode(signature)
      end

      other_names = ""
      aliases = []
      aliases.concat(wiki_user.properties("P1559").compact.map{|a| a.value.text})
      aliases.concat(wiki_user.aliases.values.compact.map{|a| a.map{|b| b.value if b.language == "en"}.compact}.flatten) rescue nil
      if aliases.length > 0
        other_names = aliases.uniq.join("|")
      end

      date_born = Date.parse(wiki_user.properties("P569").compact.map{|a| a.value.time if a.precision_key == :day}.compact.first) rescue nil
      date_died = Date.parse(wiki_user.properties("P570").compact.map{|a| a.value.time if a.precision_key == :day}.compact.first) rescue nil

      organizations = []
      ["P108", "P1416"].each do |property|
        wiki_user.properties(property).each do |org|
          organization = wiki_user_organization(wiki_user, org, property)
          next if organization[:end_year].nil?
          organizations << organization
        end
      end

      {
        family: family,
        given: given,
        particle: particle,
        other_names: other_names,
        country: country,
        country_code: country_code,
        keywords: keywords,
        orcid: nil, #might have ORCID but null it out
        image_url: image_url,
        signature_url: signature_url,
        date_born: date_born,
        date_died: date_died,
        organizations: organizations
      }
    end

    def wiki_user_organization(wiki_user, org, property)
      start_time = { year: nil, month: nil, day: nil }
      end_time = { year: nil, month: nil, day: nil }

      qualifiers = wiki_user.hash[:claims][property.to_sym]
                            .select{|a| a[:mainsnak][:datavalue][:value][:id] == org.id}
                            .first
                            .qualifiers rescue nil
      if !qualifiers.nil?
        start_precision = qualifiers[:P580].first
                                           .datavalue
                                           .value
                                           .precision rescue nil
        if !start_precision.nil?
          start_time = parse_wikitime(qualifiers[:P580].first.datavalue.value.time, start_precision)
        end

        end_precision = qualifiers[:P582].first
                                         .datavalue
                                         .value
                                         .precision rescue nil
        if !end_precision.nil?
          end_time = parse_wikitime(qualifiers[:P582].first.datavalue.value.time, end_precision)
        end
      end
      {
        name: org.title,
        wikidata: org.id,
        ringgold: nil,
        grid: nil,
        address: nil,
        start_day: start_time[:day],
        start_month: start_time[:month],
        start_year: start_time[:year],
        end_day: end_time[:day],
        end_month: end_time[:month],
        end_year: end_time[:year]
      }
    end

    def wiki_user_by_orcid(orcid)
      data = {}
      @sparql.query(wikidata_by_orcid_query(orcid)).each_solution do |solution|
        data[:twitter] = solution.to_h[:twitter] rescue nil
      end
      data
    end

    def existing_wikicodes
      User.pluck(:wikidata).compact
    end

    def destroyed_users
      DestroyedUser.pluck(:identifier).compact
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

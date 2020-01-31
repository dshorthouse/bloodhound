# encoding: utf-8

class String
  def is_orcid?
    orcid_pattern = /^(\d{4}-){3}\d{3}[0-9X]{1}$/
    orcid_pattern.match?(self)
  end
  def is_wiki_id?
    wiki_pattern = /^Q[0-9]{1,}$/
    wiki_pattern.match?(self)
  end
end

module Sinatra
  module Bloodhound
    module Helpers

      def base_url
        @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
      end

      def check_identifier
        if !params[:id].is_orcid? && !params[:id].is_wiki_id?
          halt 404
        end
      end

      def check_redirect
        destroyed_user = DestroyedUser.where("identifier = ?", params[:id])
                                      .where.not(redirect_to: nil)
        if !destroyed_user.empty?
          dest = request.path.sub(params[:id], destroyed_user.first.redirect_to)
          redirect "#{dest}", 301
        end
      end

      def check_user_public
        if !@viewed_user && !@viewed_user.is_public?
          halt 404
        end
      end

      def clear_caches(user)
        cache_clear "fragments/#{user.identifier}"
        cache_clear "fragments/#{user.identifier}-trainer"
        cache_clear "blocks/#{user.identifier}-stats"
      end

      def search_agent(opts = { item_size: 25 })
        @results = []
        filters = []
        searched_term = params[:q]
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        size = opts[:item_size] || search_size
        client = Elasticsearch::Client.new
        body = build_name_query(searched_term)
        from = (page -1) * size

        response = client.search index: Settings.elastic.agent_index, from: from, size: size, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: size, page: page)
        @results = results[:hits]
      end

      def search_agents(search)
        client = Elasticsearch::Client.new
        body = build_name_query(search)
        response = client.search index: Settings.elastic.agent_index, size: 25, body: body
        results = response["hits"].deep_symbolize_keys
        results[:hits].map{|n| n[:_source].merge(score: n[:_score]) }.compact rescue []
      end

      def search_user
        @results = []
        searched_term = params[:q]
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new
        body = build_name_query(searched_term)
        from = (page -1) * 30

        response = client.search index: Settings.elastic.user_index, from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
        @results = results[:hits]
      end

      def latest_claims(type = "living")
        user_type = (type == "living") ? { orcid: nil } : { wikidata: nil }
        subq = UserOccurrence.select("user_occurrences.user_id AS user_id, MAX(user_occurrences.created) AS created")
                              .group("user_occurrences.user_id")

        qry = UserOccurrence.select(:user_id, :created_by, :created)
                            .joins(:user)
                            .joins("INNER JOIN (#{subq.to_sql}) sub ON sub.user_id = user_occurrences.user_id AND sub.created = user_occurrences.created")
                            .preload(:user, :claimant)
                            .where("user_occurrences.user_id != user_occurrences.created_by")
                            .where.not(users: user_type)
                            .order(created: :desc)
                            .distinct

        @pagy, @results = pagy_arel(qry, items: 20)
      end

      def find_user(id)
        if id.is_orcid?
          User.find_by_orcid(id)
        elsif id.is_wiki_id?
          User.find_by_wikidata(id)
        else
          User.find(id)
        end
      end

      def search_organization
        searched_term = params[:q]
        @results = []
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new
        body = build_organization_query(searched_term)
        from = (page -1) * 30

        response = client.search index: Settings.elastic.organization_index, from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
        @results = results[:hits]
      end

      def search_dataset
        searched_term = params[:q]
        @results = []
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new
        body = build_dataset_query(searched_term)
        from = (page -1) * 30

        response = client.search index: Settings.elastic.dataset_index, from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
        @results = results[:hits]
      end

      def example_profiles
        @results = User.where(is_public: true).limit(6).order(Arel.sql("RAND()"))
      end

      def candidate_agents(user)
        agents = search_agents(user.fullname)

        abbreviated_name = [user.initials, user.family].join(" ")
        agents.concat search_agents(abbreviated_name)

        full_names = [user.fullname.dup]
        full_names << abbreviated_name
        given_names = [user.given.dup]
        given_names << user.initials.dup

        if !user.other_names.nil?
          user.other_names.split("|").each do |other_name|
            #Attempt to ignore botanist abbreviation or naked family name, often as "other" name in wikidata
            next if user.family.include?(other_name.gsub(".",""))

            #Attempt to tack on family name because single given name often in ORCID
            if !other_name.include?(" ")
              other_name = [other_name, user.family].join(" ")
            end

            full_names << other_name
            agents.concat search_agents(other_name)

            parsed_other_name = DwcAgent.parse(other_name)[0] rescue nil

            if !parsed_other_name.nil? && !parsed_other_name.given.nil?
              abbreviated_name = [parsed_other_name.initials[0..-3], parsed_other_name.family].join(" ")
              full_names << abbreviated_name
              agents.concat search_agents(abbreviated_name)
              given = parsed_other_name.given
              given_names << given
              given_names << given.gsub(/([[:upper:]])[[:lower:]]+/, '\1.')
                                  .gsub(/\s+/, '')
            end
          end
        end

        given_names.uniq!
        full_names.uniq!

        if !params.has_key?(:relaxed) || params[:relaxed] == "0"
          remove_agents = []

          agents.each do |a|
            # Boost score above cutoff if exact match to name or abbreviation
            if full_names.include?(a[:fullname])
              a[:score] += 40
            end
            scores = given_names.map{ |g| DwcAgent.similarity_score(g, a[:given]) }
            remove_agents << a[:id] if scores.reject{|a| a == 0}.empty?
            remove_agents << a[:id] if scores.include?(0) && given_names.count == 2
          end

          agents.delete_if{|a| remove_agents.include?(a[:id]) || a[:score] < 40 }
        end

        agents.compact.uniq.sort_by{|a| a[:score]}.reverse
      end

      def occurrences_by_score(id_scores, user)
        scores = {}
        id_scores.sort{|a,b| b[:score] <=> a[:score]}
                 .each{|a| scores[a[:id]] = a[:score] }

        occurrences_by_agent_ids(scores.keys)
          .where.not(occurrence_id: user.user_occurrences.select(:occurrence_id))
          .pluck(:agent_id, :typeStatus, :occurrence_id)
          .sort_by{|o| [ scores.fetch(o[0]), o[1].nil? ? "" : o[1] ] }
          .reverse
          .map(&:last)
      end

      def occurrences_by_agent_ids(agent_ids = [])
        OccurrenceRecorder.where({ agent_id: agent_ids })
                          .union_all(OccurrenceDeterminer.where(agent_id: agent_ids))
                          .includes(:occurrence)
      end

      def search_size
        if [25,50,100,250].include?(params[:per].to_i)
          params[:per].to_i
        else
          25
        end
      end

      def specimen_pager(occurrence_ids)
        @total = occurrence_ids.length
        if @page*search_size > @total && @total > search_size
          @page = @total % search_size == 0 ? @total/search_size : (@total/search_size).to_i + 1
        end
        if @total < search_size || @total == search_size
          @page = 1
        end
        @pagy, results = pagy_array(occurrence_ids, items: search_size, page: @page)
        @results = Occurrence.find(occurrence_ids[@pagy.offset, search_size])
        if @total > 0 && @results.empty?
          @page -= 1
          @pagy, results = pagy_array(occurrence_ids, items: search_size, page: @page)
          @results = Occurrence.find(occurrence_ids[@pagy.offset, search_size])
        end
      end

      def specimen_filters
        if params[:action] && !["collected","identified"].include?(params[:action])
          halt 404, haml(:oops)
        elsif params[:action] && ["collected","identified"].include?(params[:action])
          if params[:action] == "collected"
            results = @viewed_user.recordings
            if params[:start_year]
              start_date = Date.new(params[:start_year].to_i)
              if start_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.eventDate_processed >= ?", start_date)
            end
            if params[:end_year]
              end_date = Date.new(params[:end_year].to_i)
              if end_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.eventDate_processed <= ?", end_date)
            end
          end
          if params[:action] == "identified"
            results = @viewed_user.identifications
            if params[:start_year]
              start_date = Date.new(params[:start_year].to_i)
              if start_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.dateIdentified_processed >= ?", start_date)
            end
            if params[:end_year]
              end_date = Date.new(params[:end_year].to_i)
              if end_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.dateIdentified_processed <= ?", end_date)
            end
          end
        else
          results = @viewed_user.visible_occurrences
        end

        if params[:country_code]
          country = IsoCountryCodes.find(params[:country_code]) rescue nil
          if country.nil?
            halt 404
          end
          results = results.where(occurrences: { countryCode: params[:country_code] })
        end

        results
      end

      def helping_specimen_filters
        if params[:action] && !["collected","identified"].include?(params[:action])
          halt 404, haml(:oops)
        elsif params[:action] && ["collected","identified"].include?(params[:action])
          results = @viewed_user.claims_received.joins(:occurrence)
          if params[:action] == "collected"
            results = results.where(@viewed_user.qry_recorded)
            if params[:start_year]
              start_date = Date.new(params[:start_year].to_i)
              if start_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.eventDate_processed >= ?", start_date)
            end
            if params[:end_year]
              end_date = Date.new(params[:end_year].to_i)
              if end_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.eventDate_processed <= ?", end_date)
            end
          end
          if params[:action] == "identified"
            results = results.where(@viewed_user.qry_identified)
            if params[:start_year]
              start_date = Date.new(params[:start_year].to_i)
              if start_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.dateIdentified_processed >= ?", start_date)
            end
            if params[:end_year]
              end_date = Date.new(params[:end_year].to_i)
              if end_date > Date.today
                halt 404, haml(:oops)
              end
              results = results.where("occurrences.dateIdentified_processed <= ?", end_date)
            end
          end
        else
          results = @viewed_user.claims_received.joins(:occurrence)
        end

        if params[:country_code]
          country = IsoCountryCodes.find(params[:country_code]) rescue nil
          if country.nil?
            halt 404
          end
          results = results.where(occurrences: { countryCode: params[:country_code] })
        end
        results
      end

      def roster
        @pagy, @results = pagy(User.where(is_public: true).order(:family))
      end

      def admin_roster
        data = User.order(visited: :desc, family: :asc)
        if params[:order] && User.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
          data = User.order("#{params[:order]} #{params[:sort]}")
        end
        @pagy, @results = pagy(data, items: 100)
      end

      def articles
        @pagy, @results = pagy(Article.order(created: :desc))
      end

      def datasets
        if params[:order] && Dataset.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
          data = Dataset.order("#{params[:order]} #{params[:sort]}")
        else
          data = Dataset.order(:title)
        end
        @pagy, @results = pagy(data)
      end

      def organizations
        if params[:order] && Organization.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
          data = Organization.active_user_organizations.order("#{params[:order]} #{params[:sort]}")
        else
          data = Organization.active_user_organizations.order(:name)
        end
        @pagy, @results = pagy(data)
      end

      def organization_redirect(path = "")
        @organization = Organization.find_by_identifier(params[:id]) rescue nil
        if @organization.nil?
          halt 404
        end
        if !@organization.wikidata.nil? && params[:id] != @organization.wikidata
          redirect "/organization/#{@organization.wikidata}#{path}"
        end
      end

      def organization
        organization_redirect
        @pagy, @results = pagy(@organization.active_users.order(:family))
      end

      def dataset_users
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt 404
        end
        @pagy, @results = pagy(@dataset.users.order(:family))
      end

      def dataset_agents
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt 404
        end

        @pagy, @results = pagy_array(@dataset.agents.to_a, items: 75)
      end

      def dataset_agents_counts
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt 404
        end

        @pagy, @results = pagy_array(@dataset.agents_occurrence_counts.to_a, items: 75)
      end

      def dataset_stats
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt {}
        end
        { people: @dataset.users.count }
      end

      def past_organization
        organization_redirect("/past")
        @pagy, @results = pagy(@organization.inactive_users.order(:family))
      end

      def organization_metrics
        organization_redirect("/metrics")
        if Organization::METRICS_YEAR_RANGE.to_a.include?(@year.to_i)
          @others_recorded = @organization.others_specimens_by_year("recorded", @year)
          @others_identified = @organization.others_specimens_by_year("identified", @year)
        else
          @others_recorded = @organization.others_specimens("recorded")
          @others_identified = @organization.others_specimens("identified")
        end
      end

      def organization_articles
        organization_redirect("/citations")
        @organization.articles
      end

      def trainers
        results = UserOccurrence.where.not({ created_by: User::BOT_IDS })
                                .where("user_occurrences.user_id != user_occurrences.created_by")
                                .group([:user_id, :created_by])
                                .pluck(:created_by)
                                .uniq
                                .map{|u| User.find(u)}
                                .sort_by{|u| u.family}
        @pagy, @results  = pagy_array(results, items: 30)
      end

      def create_user
        if params[:identifier] && !params[:identifier].empty?
          if params[:identifier].is_orcid?
            new_user = User.find_or_create_by({ orcid: params[:identifier] })
            flash.next[:new_user] = { fullname: new_user.fullname, slug: new_user.orcid }
          elsif params[:identifier].is_wiki_id?
            new_user = User.find_or_create_by({ wikidata: params[:identifier] })
            if !new_user.valid_wikicontent?
              flash.next[:new_user] = { fullname: params[:identifier], slug: nil }
              new_user.delete
            else
              flash.next[:new_user] = { fullname: new_user.fullname, slug: new_user.wikidata }
            end
          else
            flash.next[:new_user] = { fullname: params[:identifier], slug: nil }
          end
        end
      end

      def user_stats(user)
        counts = user.country_counts
        cited = user.cited_specimens_counts
        helped = user.helped_counts

        identified_count = counts.values.reduce(0) {
          |sum, val| sum + val[:identified]
        }
        recorded_count = counts.values.reduce(0) {
          |sum, val| sum + val[:recorded]
        }
        countries_identified = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:identified] > 0
            data[code[0]] = code[1][:identified]
          end
        end
        countries_recorded = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:recorded] > 0
            data[code[0]] = code[1][:recorded]
          end
        end

        r = user.recorded_bins
        r.each{|k,v| r[k] = [0,v]}

        i = user.identified_bins
        i.each {|k,v| i[k] = [v,0]}

        activity_dates = r.merge(i) do |k, first_val, second_val|
          [[first_val[0], second_val[0]].max, [first_val[1], second_val[1]].max]
        end

        {
          specimens: {
            identified: identified_count,
            recorded: recorded_count
          },
          attributions: {
            helped: helped.count,
            number: helped.values.reduce(:+)
          },
          countries: {
            identified: countries_identified,
            recorded: countries_recorded
          },
          articles: {
            specimens_cited: cited.map(&:second).reduce(:+),
            number: cited.count
          },
          activity_dates: activity_dates
                .delete_if{|k,v| k > Date.today.year || k <= 1700 || v == [0,0] }
                .sort
                .map{|k,v| v.flatten.unshift(k.to_s) }
        }
      end

      def helping_user_stats(user)
        counts = user.country_counts_helped

        identified_count = counts.values.reduce(0) {
          |sum, val| sum + val[:identified]
        }
        recorded_count = counts.values.reduce(0) {
          |sum, val| sum + val[:recorded]
        }
        countries_identified = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:identified] > 0
            data[code[0]] = code[1][:identified]
          end
        end
        countries_recorded = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:recorded] > 0
            data[code[0]] = code[1][:recorded]
          end
        end

        r = user.recorded_bins_helped
        r.each{|k,v| r[k] = [0,v]}

        i = user.identified_bins_helped
        i.each {|k,v| i[k] = [v,0]}

        activity_dates = r.merge(i) do |k, first_val, second_val|
          [[first_val[0], second_val[0]].max, [first_val[1], second_val[1]].max]
        end

        {
          specimens: {
            identified: identified_count,
            recorded: recorded_count
          },
          countries: {
            identified: countries_identified,
            recorded: countries_recorded
          },
          activity_dates: activity_dates
                .delete_if{|k,v| k > Date.today.year || k <= 1700 || v == [0,0] }
                .sort
                .map{|k,v| v.flatten.unshift(k.to_s) }
        }
      end

    end
  end
end

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
          halt 404, haml(:oops)
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
          halt 404, haml(:oops)
        end
      end

      def search_agent
        @results = []
        filters = []
        searched_term = params[:q]
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new
        body = build_name_query(searched_term)
        from = (page -1) * search_size

        response = client.search index: Settings.elastic_agent_index, type: "agent", from: from, size: search_size, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total], items: search_size, page: page)
        @results = results[:hits]
      end

      def search_agents(search)
        client = Elasticsearch::Client.new
        body = build_name_query(search)
        response = client.search index: Settings.elastic_agent_index, type: "agent", size: 25, body: body
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

        response = client.search index: Settings.elastic_user_index, type: "user", from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total], items: 30, page: page)
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
                            .where("user_occurrences.visible = true")
                            .where("user_occurrences.user_id != user_occurrences.created_by")
                            .where.not(users: user_type)
                            .order(created: :desc)
                            .distinct

        @pagy, @results = pagy(qry, items: 20)
      end

      def find_user(id)
        if id.is_orcid?
          User.find_by_orcid(id)
        elsif id.is_wiki_id?
          User.find_by_wikidata(id)
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

        response = client.search index: Settings.elastic_organization_index, type: "organization", from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total], items: 30, page: page)
        @results = results[:hits]
      end

      def example_profiles
        @results = User.where(is_public: true).limit(6).order(Arel.sql("RAND()"))
      end

      def candidate_agents(user)
        agents = search_agents(user.fullname)

        given_names = [user.given]

        if !user.other_names.nil?
          user.other_names.split("|").each do |other_name|
            if !other_name.include?(" ") && other_name != user.family
              other_name = [other_name, user.family].join(" ")
            end
            agents.concat search_agents(other_name)
            given = DwcAgent.parse(other_name)[0].given rescue nil
            given_names << given if !given.nil?
          end
        end

        #Remove wildly different search results if not a relaxed view
        if !params.has_key?(:relaxed) || params[:relaxed] == "0"
          keepers = []
          agents.each do |a|
            #Keep if no given name
            if a[:given].nil?
              keepers << a
              next
            end
            #Keep if agent given name is similar to a provided given name
            given_names.uniq.each do |g|
              if DwcAgent.similarity_score(g, a[:given]) > 0
                keepers << a
              end
            end
          end
          agents.delete_if{|a| !keepers.include?(a) || a[:score] < 40 }
        end

        agents.compact.uniq.sort_by{|a| a[:score]}.reverse
      end

      def occurrences_by_score(id_scores, user)
        scores = {}
        id_scores.sort{|a,b| b[:score] <=> a[:score]}
                 .each{|a| scores[a[:id]] = a[:score] }

        occurrences_by_agent_ids(scores.keys).where.not(occurrence_id: user.user_occurrences.select(:occurrence_id))
                                          .pluck(:agent_id, :typeStatus, :occurrence_id)
                                          .sort_by{|o| [ scores.fetch(o[0]), o[1].nil? ? "" : o[1] ] }
                                          .reverse
                                          .map(&:last)
      end

      def occurrences_by_agent_ids(agent_ids = [])
        OccurrenceRecorder.where(agent_id: agent_ids)
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
          halt 404, haml(:oops)
        end
        if !@organization.wikidata.nil? && params[:id] != @organization.wikidata
          redirect "/organization/#{@organization.wikidata}#{path}"
        end
      end

      def organization
        organization_redirect
        @pagy, @results = pagy(@organization.active_users.order(:family))
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
        results = UserOccurrence.where.not(created_by: User::BOT_IDS)
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
            session[:new_user] = { fullname: new_user.fullname, slug: new_user.orcid }
          elsif params[:identifier].is_wiki_id?
            new_user = User.find_or_create_by({ wikidata: params[:identifier] })
            if !new_user.valid_wikicontent?
              session[:new_user] = { fullname: params[:identifier], slug: nil }
              new_user.delete
            else
              session[:new_user] = { fullname: new_user.fullname, slug: new_user.wikidata }
            end
          else
            session[:new_user] = { fullname: params[:identifier], slug: nil }
          end
        end
      end

    end
  end
end
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

      def root
        Sinatra::Application.settings.root
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

        response = client.search index: settings.elastic_agent_index, type: "agent", from: from, size: search_size, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total], items: search_size, page: page)
        @results = results[:hits]
      end

      def search_agents(search)
        client = Elasticsearch::Client.new
        body = build_name_query(search)
        response = client.search index: settings.elastic_agent_index, type: "agent", size: 25, body: body
        results = response["hits"].deep_symbolize_keys
        results[:hits].map{|n| n[:_source].merge(score: n[:_score]) } rescue []
      end

      def search_user
        @results = []
        searched_term = params[:q]
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new
        body = build_name_query(searched_term)
        from = (page -1) * 30

        response = client.search index: settings.elastic_user_index, type: "user", from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total], items: 30, page: page)
        @results = results[:hits]
      end

      def search_users(search)
        client = Elasticsearch::Client.new
        body = build_name_query(search)
        response = client.search index: settings.elastic_user_index, type: "user", body: body
        results = response["hits"].deep_symbolize_keys
        results[:hits].map{|n| n[:_source].merge(score: n[:_score]) } rescue []
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

        response = client.search index: settings.elastic_organization_index, type: "organization", from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total], items: 30, page: page)
        @results = results[:hits]
      end

      def example_profiles
        @results = User.where(is_public: true).limit(6).order(Arel.sql("RAND()"))
      end

      def candidate_agents(user)
        agents = search_agents(user.fullname)

        if !user.other_names.nil?
          user.other_names.split("|").each do |other_name|
            if !other_name.include?(" ") && other_name != user.family
              other_name = [other_name, user.family].join(" ")
            end
            agents.concat search_agents(other_name)
          end
        end

        #TODO: accommodate the other_names when given portion in other_names is a nickname, entirely different from user.given
        if !params.has_key?(:relaxed) || params[:relaxed] == "0"
          agents.delete_if do |key,value|
            !user.given.nil? && !key[:given].nil? && DwcAgent.similarity_score(key[:given], user.given) == 0
          end
        end
        agents.compact.uniq
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
        if [25,100,250].include?(params[:per].to_i)
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
        if @total < search_size
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
        @others_recorded = @organization.users_others_specimens_recorded
        @others_identified = @organization.users_others_specimens_identified
      end

    end
  end
end
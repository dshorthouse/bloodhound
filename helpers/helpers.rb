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

      def set_session
        if session[:omniauth]
          @user = session[:omniauth]
        end
      end

      def update_session
        user = User.find(@user[:id]).reload
        user_hash = user.as_json.symbolize_keys
        user_hash[:fullname] = user.fullname
        user_hash[:current_organization] = user.current_organization.as_json.symbolize_keys rescue nil
        session[:omniauth] = user_hash
        set_session
      end

      def protected!
        return if authorized?
        halt 401, haml(:not_authorized)
      end

      def authorized?
        defined? @user
      end

      def admin_protected!
        return if admin_authorized?
        halt 401, haml(:not_authorized)
      end

      def admin_authorized?
        defined?(@user) && is_admin?
      end

      def h(text)
        Rack::Utils.escape_html(text)
      end

      def number_with_delimiter(number, default_options = {})
        options = {
          :delimiter => ','
        }.merge(default_options)
        number.to_s.reverse.gsub(/(\d{3}(?=(\d)))/, "\\1#{options[:delimiter]}").reverse
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

      def search_agents(family, given = nil)
        client = Elasticsearch::Client.new
        body = {
          query: {
            bool: {
              must: [
                match: { "family" => family }
              ],
              should: [
                { match: { "given" => given } }
              ]
            }
          }
        }
        response = client.search index: settings.elastic_agent_index, type: "agent", size: 25, body: body
        results = response["hits"].deep_symbolize_keys
        results[:hits].map{|n| n[:_source].merge(score: n[:_score]) } rescue []
      end

      def search_user
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

      def search_users(family, given = nil)
        client = Elasticsearch::Client.new
        body = {
          query: {
            bool: {
              must: [
                match: { "family" => family }
              ],
              should: [
                { match: { "given" => given } }
              ]
            }
          }
        }
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
        count = User.where(is_public: true).count
        random_offset = rand(count)
        @results = User.where(is_public: true)
                       .offset(random_offset).limit(6)
      end

      def candidate_agents
        agents = search_agents(@user[:family], @user[:given])

        if !@user[:other_names].nil?
          @user[:other_names].split("|").each do |other_name|
            next if !other_name.include?(" ")
            begin
              parsed = Namae.parse other_name.gsub(/\./, ".\s")
              name = DwcAgent.clean(parsed[0])
              family = !name[:family].nil? ? name[:family] : nil
              given = !name[:given].nil? ? name[:given] : nil
              if !family.nil?
                agents.concat search_agents(family, given)
              end
            rescue
            end
          end
        end

        if !params.has_key?(:relaxed) || params[:relaxed] == "0"
          agents.delete_if do |key,value|
            !@user[:given].nil? && !key[:given].nil? && DwcAgent.similarity_score(key[:given], @user[:given]) == 0
          end
        end
        agents.compact.uniq
      end

      def admin_candidate_agents
        agents = search_agents(@admin_user.family, @admin_user.given)

        if !@admin_user.other_names.nil?
          @admin_user.other_names.split("|").each do |other_name|
            next if !other_name.include?(" ")
            begin
              parsed = Namae.parse other_name.gsub(/\./, ".\s")
              name = DwcAgent.clean(parsed[0])
              family = !name[:family].nil? ? name[:family] : ""
              given = !name[:given].nil? ? name[:given] : ""
              if !family.blank?
                agents.concat search_agents(family, given)
              end
            rescue
            end
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
        if @page*search_size > @total
          @page = @total/search_size.to_i + 1
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
        @pagy, @results = pagy(User.order(visited: :desc, family: :asc))
      end

      def articles
        @pagy, @results = pagy(Article.order(created: :desc))
      end

      def organizations
        @pagy, @results = pagy(Organization.active_user_organizations.order(:name))
      end

      def organization
        organizations = Organization.where(ringgold: params[:id]).or(Organization.where(grid: params[:id]))
        if !organizations.empty?
          @organization = organizations.first
          @pagy, @results = pagy(@organization.active_users.order(:family))
        else
          status 404
          haml :oops
        end
      end

      def past_organization
        organizations = Organization.where(ringgold: params[:id]).or(Organization.where(grid: params[:id]))
        if !organizations.empty?
          @organization = organizations.first
          @pagy, @results = pagy(@organization.inactive_users.order(:family))
        else
          status 404
          haml :oops
        end
      end

      def build_name_query(search)
        parsed = Namae.parse search
        name = DwcAgent.clean(parsed[0]) rescue { family: nil, given: nil }
        family = !name[:family].nil? ? name[:family] : ""
        given = !name[:given].nil? ? name[:given] : ""
        {
          query: {
            bool: {
              must: [
                match: { "family" => family }
              ],
              should: [
                { match: { "family" => search } },
                { match: { "given" => given } }
              ]
            }
          }
        }
      end

      def build_organization_query(search)
        {
          query: {
            multi_match: {
              query: search,
              type: :best_fields,
              fields: ["name^3", "address"]
            }
          }
        }
      end

      def format_agent(n)
        { id: n[:_source][:id],
          score: n[:_score],
          name: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", ")
        }
      end

      def format_agents
        @results.map{ |n|
          { id: n[:_source][:id],
            score: n[:_score],
            name: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", "),
            fullname: [n[:_source][:given].presence, n[:_source][:family].presence].compact.join(" ")
          }
        }
      end

      def format_users
        @results.map{ |n|
          { id: n[:_source][:id],
            score: n[:_score],
            orcid: n[:_source][:orcid],
            wikidata: n[:_source][:wikidata],
            name: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", "),
            fullname: [n[:_source][:given].presence, n[:_source][:family].presence].compact.join(" ")
          }
        }
      end

      def format_organizations
        @results.map{ |n|
          { id: n[:_source][:id],
            score: n[:_score],
            name: n[:_source][:name],
            address: n[:_source][:address],
            isni: n[:_source][:isni],
            ringgold: n[:_source][:ringgold],
            grid: n[:_source][:grid],
            preferred: n[:_source][:preferred]
          }
        }
      end

      def format_lifespan(user)
        born = !user.date_born.nil? ? user.date_born.to_formatted_s(:long) : "?"
        died = !user.date_died.nil? ? user.date_died.to_formatted_s(:long) : "?"
        "(" + [born,died].join(" &ndash; ") + ")"
      end

      def cycle
        %w{even odd}[@_cycle = ((@_cycle || -1) + 1) % 2]
      end

      def checked_tag(user_action, action)
        (user_action == action) ? "checked" : ""
      end

      def active_class(user_action, action)
        (user_action == action) ? "active" : ""
      end

      def is_public?
        @user[:is_public] ? true : false
      end

      def is_user_public?
        @admin_user.is_public? ? true : false
      end

      def is_admin?
        @user[:is_admin] ? true : false
      end

      def to_csv(model, records)
        CSV.generate do |csv|
          csv << model.attribute_names
          records.each { |r| csv << r.attributes.values }
        end
      end

      def csv_stream_headers(file_name = "download")
        content_type "application/csv"
        attachment !params[:orcid].nil? ? "#{params[:orcid]}.csv" : "#{file_name}.csv"
        cache_control :no_cache
        headers.delete("Content-Length")
      end

      def csv_stream_occurrences(occurrences)
        Enumerator.new do |y|
          header = ["action"].concat(Occurrence.attribute_names)
          y << CSV::Row.new(header, header, true).to_s
          occurrences.find_each do |o|
            data = [o.action].concat(o.occurrence.attributes.values)
            y << CSV::Row.new(header, data).to_s
          end
        end
      end

      def csv_stream_candidates(occurrences)
        Enumerator.new do |y|
          header = ["action"].concat(Occurrence.attribute_names)
          y << CSV::Row.new(header, header, true).to_s
          if !occurrences.empty?
            occurrences.each do |o|
              data = [""].concat(o.occurrence.attributes.values)
              y << CSV::Row.new(header, data).to_s
            end
          end
        end
      end

    end
  end
end
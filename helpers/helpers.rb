# encoding: utf-8

class String
  def is_orcid?
    orcid_pattern = /^(\d{4}-){3}\d{3}[0-9X]{1}$/
    orcid_pattern.match?(self)
  end
end

module Sinatra
  module Bloodhound
    module Helpers

      def set_session
        if session[:omniauth]
          @user = session[:omniauth]
        end
      end

      def update_session
        user = User.find(@user[:id]).reload
        user_hash = user.as_json.symbolize_keys
        user_hash[:fullname] = user.fullname
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

      def paginate(collection)
          options = {
           inner_window: 3,
           outer_window: 3,
           previous_label: '&laquo;',
           next_label: '&raquo;'
          }
         will_paginate collection, options
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
        search_size = (params[:per] || 20).to_i

        client = Elasticsearch::Client.new
        body = build_name_query(searched_term)
        from = (page -1) * search_size

        response = client.search index: settings.elastic_index, type: "agent", from: from, size: search_size, body: body
        results = response["hits"].deep_symbolize_keys

        @results = WillPaginate::Collection.create(page, search_size, results[:total]) do |pager|
          pager.replace results[:hits]
        end
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
        response = client.search index: settings.elastic_index, type: "agent", body: body
        results = response["hits"].deep_symbolize_keys
        results[:hits].map{|n| n[:_source].merge(score: n[:_score]) } rescue []
      end

      def occurrences_by_score(id_scores, user_id = @user[:id])
        user = User.find(user_id)
        linked_ids = user.user_occurrences.pluck(:occurrence_id)

        scores = {}
        id_scores.sort{|a,b| b[:score] <=> a[:score]}
                 .each{|a| scores[a[:id]] = a[:score] }

        recorded = OccurrenceRecorder.where(agent_id: scores.keys)
                                     .where.not(occurrence_id: linked_ids)
                                     .pluck(:agent_id, :occurrence_id)
        determined = OccurrenceDeterminer.where(agent_id: scores.keys)
                                         .where.not(occurrence_id: linked_ids)
                                         .pluck(:agent_id, :occurrence_id)
        (recorded + determined).uniq
                               .sort_by{|o| scores.fetch(o[0])}
                               .reverse
                               .map(&:last)
      end

      def specimen_pager(occurrence_ids)
        @total = occurrence_ids.length
        if @page*@search_size > @total
          @page = @total/@search_size.to_i + 1
        end
        @results = WillPaginate::Collection.create(@page, @search_size, occurrence_ids.length) do |pager|
          pager.replace Occurrence.find(occurrence_ids[pager.offset, pager.per_page])
        end
        if @total > 0 && @results.empty?
          @page -= 1
          @results = WillPaginate::Collection.create(@page, @search_size, occurrence_ids.length) do |pager|
            pager.replace Occurrence.find(occurrence_ids[pager.offset, pager.per_page])
          end
        end
        @results
      end

      def roster
        @results = User.joins(:user_occurrences)
                       .where(is_public: true)
                       .where("user_occurrences.visible": true)
                       .order(:family)
                       .distinct
                       .paginate :page => params[:page]
      end

      def admin_roster
        @results = User.order(:family)
                       .paginate :page => params[:page]
      end

      def build_name_query(search)
        parsed = Namae.parse search
        name = DwcAgent.clean(parsed[0])
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

      def format_agent(n)
        { id: n[:_source][:id],
          name: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", ")
        }
      end

      def format_agents
        @results.map{ |n|
          { id: n[:_source][:id],
            name: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", "),
            fullname: [n[:_source][:given].presence, n[:_source][:family].presence].compact.join(" ")
          }
        }
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

    end
  end
end
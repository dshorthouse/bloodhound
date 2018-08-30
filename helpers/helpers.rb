# encoding: utf-8

module Sinatra
  module Bloodhound
    module Helpers

      def set_session
        if session[:omniauth]
          @user = session[:omniauth]
        end
      end

      def get_orcid_profile(uid)
        response = RestClient::Request.execute(
          method: :get,
          url: Sinatra::Application.settings.orcid_api_url + uid,
          headers: { accept: 'application/orcid+json' }
        )
        JSON.parse(response, :symbolize_names => true)
      end

      def protected!
        return if authorized?
        halt 401, "Not authorized\n"
      end

      def authorized?
        defined? @user
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

      def search_agents(family, given)
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

      def format_agent(n)
        orcid = n[:_source][:orcid].presence if n[:_source].has_key? :orcid
        { id: n[:_source][:id],
          name: [n[:_source][:personal][:family].presence, n[:_source][:personal][:given].presence].compact.join(", "),
          orcid: orcid,
          collector_index:  n[:_source][:collector_index]
        }
      end

      def cycle
        %w{even odd}[@_cycle = ((@_cycle || -1) + 1) % 2]
      end

    end
  end
end
# encoding: utf-8

module Sinatra
  module Bloodhound
    module AgentHelpers

      def search_agent(opts = { item_size: 25 })
        @results = []
        filters = []
        searched_term = params[:q] || params[:agent]
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        size = opts[:item_size] || search_size
        client = Elasticsearch::Client.new url: Settings.elastic.server
        body = build_name_query(searched_term)
        from = (page -1) * size

        response = client.search index: Settings.elastic.agent_index, from: from, size: size, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: size, page: page)
        @results = results[:hits]
      end

      def search_agents(search)
        client = Elasticsearch::Client.new url: Settings.elastic.server
        body = build_name_query(search)
        response = client.search index: Settings.elastic.agent_index, size: 25, body: body
        results = response["hits"].deep_symbolize_keys
        results[:hits].map{|n| n[:_source].merge(score: n[:_score]) }.compact rescue []
      end

      def candidate_agents(user)
        agents = search_agents(user.fullname)
        #full_names = [user.fullname.dup]
        #given_names = [user.given.dup]

        #initials = user.initials
        #initials.split(".").each_with_index do |element, index|
        #  abbreviated_name = [initials[0..index*2+1], user.family].join(" ")
        #  agents.concat search_agents(abbreviated_name)
        #  full_names << abbreviated_name
        #  given_names << initials[0..index*2+1].dup
        #end

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

#        given_names.sort_by!(&:length).reverse!.uniq!
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

    end
  end
end

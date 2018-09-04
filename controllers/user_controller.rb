# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module UserController

        def self.registered(app)

          #/auth/orcid is automatically added by OmniAuth

          app.get '/auth/orcid/callback' do
            session_data = request.env['omniauth.auth'].deep_symbolize_keys
            orcid = session_data[:uid]
            family = session_data[:info][:last_name] rescue nil
            given = session_data[:info][:first_name] rescue nil
            email = session_data[:info][:email] rescue nil
            other_names = session_data[:extra][:raw_info][:other_names] rescue []
            user = User.create_with(family: family, given: given, orcid: session_data[:uid], email: email)
                       .find_or_create_by(orcid: orcid)
                       .as_json.symbolize_keys
            
            user[:other_names] = other_names
            session[:omniauth] = user
            redirect '/'
          end

          app.get '/profile' do
            protected!

            page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i
            occurrences = User.find(@user[:id]).user_occurrence_occurrences

            @total = occurrences.length

            @results = WillPaginate::Collection.create(page, search_size, occurrences.length) do |pager|
              pager.replace occurrences[pager.offset, pager.per_page]
            end

            haml :profile
          end

          app.get '/candidates' do
            protected!
            occurrence_ids = []
            page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i

            if @user[:family].nil?
              @results = []
              @total = nil
            else
              agents = search_agents(@user[:family], @user[:given])

              if !@user[:other_names].empty?
                @user[:other_names].each do |other_name|
                  parsed = Namae.parse other_name
                  name = ::Bloodhound::AgentUtility.clean(parsed[0])
                  family = !name[:family].nil? ? name[:family] : ""
                  given = !name[:given].nil? ? name[:given] : ""
                  agents.concat search_agents(@user[:family], @user[:given])
                end
              end

              uniq_agents = agents.compact.uniq

              if !uniq_agents.empty?
                scores = {}
                uniq_agents.each{|a| scores[a[:id]] = a[:score] }
                linked_ids = User.find(@user[:id]).occurrences.pluck(:id)
                recorded = OccurrenceRecorder.where(agent_id: scores.keys)
                                             .where.not(occurrence_id: linked_ids)
                                             .pluck(:agent_id, :occurrence_id)
                determined = OccurrenceDeterminer.where(agent_id: scores.keys)
                                                 .where.not(occurrence_id: linked_ids)
                                                 .pluck(:agent_id, :occurrence_id)
                occurrence_ids = (determined + recorded).uniq
                                                        .sort_by{|o| scores.fetch(o[0])}
                                                        .reverse
                                                        .map(&:last)
              end

              @total = occurrence_ids.length

              @results = WillPaginate::Collection.create(page, search_size, occurrence_ids.length) do |pager|
                pager.replace Occurrence.find(occurrence_ids[pager.offset, pager.per_page])
              end
            end

            haml :candidates
          end

          app.get '/candidates/agent/:id' do
            protected!
            occurrence_ids = []
            page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i

            @searched_user = Agent.find(params[:id])

            recorded = OccurrenceRecorder.where(agent_id: @searched_user.id).pluck(:occurrence_id)
            determined = OccurrenceDeterminer.where(agent_id: @searched_user.id).pluck(:occurrence_id)
            occurrence_ids = (recorded + determined).uniq

            @total = occurrence_ids.length

            @results = WillPaginate::Collection.create(page, search_size, occurrence_ids.length) do |pager|
              pager.replace Occurrence.find(occurrence_ids[pager.offset, pager.per_page])
            end
            haml :candidates_agent
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

        end

      end
    end
  end
end
# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module UserController

        def self.registered(app)

          #/auth/orcid is automatically added by OmniAuth

          app.get '/profile' do
            protected!
            @result = get_orcid_profile(@user[:orcid])
            haml :profile
          end

          app.get '/candidates' do
            protected!
            occurrence_ids = []
            page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i

            agents = search_agents(@user[:family], @user[:given])

            if !agents.empty?
              scores = {}
              agents.each{|a| scores[a[:id]] = a[:score] }
              linked_ids = User.find(@user[:id]).occurrences.pluck(:id)
              recorded = OccurrenceRecorder.where(agent_id: scores.keys)
                                           .where.not(occurrence_id: linked_ids)
                                           .pluck(:agent_id, :occurrence_id)
              determined = OccurrenceDeterminer.where(agent_id: scores.keys)
                                               .where.not(occurrence_id: linked_ids)
                                               .pluck(:agent_id, :occurrence_id)
              occurrence_ids = (recorded + determined).uniq
                                                      .sort_by{|o| scores.fetch(o[0])}
                                                      .reverse
                                                      .map(&:last)
            end

            @total = occurrence_ids.length

            @results = WillPaginate::Collection.create(page, search_size, occurrence_ids.length) do |pager|
              pager.replace Occurrence.find(occurrence_ids[pager.offset, pager.per_page])
            end
            haml :candidates
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/auth/orcid/callback' do
            session_data = request.env['omniauth.auth'].deep_symbolize_keys
            user = User.create_with(
                          family: session_data[:info][:last_name],
                          given: session_data[:info][:first_name],
                          orcid: session_data[:uid],
                          email: session_data[:info][:email])
                       .find_or_create_by(orcid: session_data[:uid])
            session[:omniauth] = user
            redirect '/'
          end

        end

      end
    end
  end
end
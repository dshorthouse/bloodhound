# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module HelpingController

        def self.registered(app)

          app.get '/help-others' do
            protected!
            @results = []
            @countries = IsoCountryCodes.for_select.group_by{|u| ActiveSupport::Inflector.transliterate(u[0][0]) }
            if params[:q]
              search_user
            end
            haml :'help/others', locals: { active_page: "help" }
          end

          app.get '/help-others/progress' do
            protected!
            latest_claims("living")
            haml :'help/progress', locals: { active_page: "help", active_tab: "living" }
          end

          app.get '/help-others/progress/deceased' do
            protected!
            latest_claims("deceased")
            haml :'help/progress', locals: { active_page: "help", active_tab: "deceased" }
          end

          app.get '/help-others/country/:country_code' do
            protected!
            country_code = params[:country_code]
            @results = []
            begin
              @country = IsoCountryCodes.find(country_code)
              @pagy, @results = pagy(User.where("country_code LIKE ?", "%#{country_code}%").order(:family), items: 30)
              haml :'help/country', locals: { active_page: "help" }
            rescue
              status 404
              haml :oops
            end
          end

          app.get '/help-others/:id' do
            protected!
            check_identifier
            @made_public = session[:made_public]
            session[:made_public] = false

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            @viewed_user = find_user(params[:id])
            if !@viewed_user
              halt 404, haml(:oops)
            end

            if @viewed_user == @user
              redirect "/profile/candidates"
            end

            if @viewed_user.family.nil?
              @results = []
              @total = nil
            else
              id_scores = candidate_agents(@viewed_user).map{|a| { id: a[:id], score: a[:score] } }.compact
              if !id_scores.empty?
                ids = id_scores.map{|a| a[:id]}
                nodes = AgentNode.where(agent_id: ids)
                if !nodes.empty?
                  (nodes.map(&:agent_id) - ids).each do |id|
                    id_scores << { id: id, score: 1 } #TODO: how to more effectively use the edge weights here?
                  end
                end
                occurrence_ids = occurrences_by_score(id_scores, @viewed_user)
              end

              specimen_pager(occurrence_ids)
            end

            haml :'help/user', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/candidates.csv' do
            protected!
            csv_stream_headers
            check_identifier
            @viewed_user = find_user(params[:id])
            if !@viewed_user
              halt 404, haml(:oops)
            end

            agent_ids = candidate_agents(@viewed_user).pluck(:id)
            records = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @viewed_user.user_occurrences.select(:occurrence_id)).limit(5_000)
            body ::Bloodhound::IO.csv_stream_candidates(records)
          end

          app.post '/help-others/:id/upload-claims' do
            protected!
            check_identifier
            @viewed_user = find_user(params[:id])
            if !@viewed_user
              halt 404, haml(:oops)
            end

            begin
              upload_file(user_id: @viewed_user.id, created_by: @user.id)
            rescue => e
              @error = e.message
            end
            haml :'help/upload'
          end

          app.put '/help-others/:id/visibility' do
            protected!
            check_identifier
            @viewed_user = find_user(params[:id])
            if !@viewed_user
              halt 404, haml(:oops)
            end
            
            if !@viewed_user.is_public
              @viewed_user.is_public = true
              @viewed_user.made_public = Time.now
              @viewed_user.save
              cache_clear "fragments/#{@viewed_user.identifier}"
              session[:made_public] = true
              redirect "/help-others/#{@viewed_user.identifier}"
            end
          end

        end

      end
    end
  end
end
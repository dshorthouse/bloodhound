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

          app.get '/help-others/candidate-count.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            user = User.find(params[:user_id].to_i)
            return { count: 0 }.to_json if user.family.nil?

            agent_ids = candidate_agents(user).pluck(:id)
            count = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: user.user_occurrences.select(:occurrence_id)).count
            { count: count }.to_json
          end

          app.get '/help-others/help' do
            protected!
            @new_user = session[:new_user]
            session[:new_user] = nil
            haml :'help/help'
          end

          app.get '/help-others/refresh.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            user = User.find(params[:user_id].to_i)
            user.update_profile
            cache_clear "fragments/#{user.identifier}"
            cache_clear "fragments/#{user.identifier}-trainer"
            { message: "ok" }.to_json
          end

          app.get '/help-others/progress' do
            protected!
            latest_claims("living")
            haml :'help/progress', locals: { active_page: "help", active_tab: "orcid" }
          end

          app.post '/help-others/add' do
            protected!
            create_user
            redirect '/help-others/help'
          end

          app.get '/help-others/progress/wikidata' do
            protected!
            latest_claims("deceased")
            haml :'help/progress', locals: { active_page: "help", active_tab: "wikidata" }
          end

          app.get '/help-others/new-people' do
            protected!
            @pagy, @results = pagy(User.where.not(orcid: nil).order(created: :desc), items: 20)
            haml :'help/new_people', locals: { active_page: "help", active_tab: "orcid" }
          end

          app.get '/help-others/new-people/wikidata' do
            protected!
            @pagy, @results = pagy(User.where.not(wikidata: nil).order(created: :desc), items: 20)
            haml :'help/new_people', locals: { active_page: "help", active_tab: "wikidata" }
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

          app.post '/help-others/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            occurrence_ids = req[:occurrence_ids].split(",")
            if !visible
              UserOccurrence.where(occurrence_id: occurrence_ids)
                            .where(user_id: req[:user_id].to_i)
                            .destroy_all
            end
            data = occurrence_ids.map{|o| { 
                user_id: req[:user_id],
                occurrence_id: o.to_i,
                created_by: @user.id,
                action: action,
                visible: visible
              }
            }
            UserOccurrence.import data, batch_size: 250, validate: false, on_duplicate_key_ignore: true
            { message: "ok" }.to_json
          end

          app.post '/help-others/user-occurrence/:occurrence_id.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            uo = UserOccurrence.new
            uo.user_id = req[:user_id].to_i
            uo.occurrence_id = params[:occurrence_id].to_i
            uo.created_by = @user.id
            uo.action = action
            uo.visible = visible
            uo.save
            { message: "ok", id: uo.id }.to_json
          end

          app.put '/help-others/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            occurrence_ids = req[:occurrence_ids].split(",")
            visible = req[:visible] rescue true
            UserOccurrence.where(id: occurrence_ids, user_id: req[:user_id].to_i)
                          .update_all({ action: req[:action], visible: visible, created_by: @user.id })
            { message: "ok" }.to_json
          end

          app.put '/help-others/user-occurrence/:id.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find_by(id: params[:id])
            uo.action = req[:action] ||= nil
            uo.visible = req[:visible] ||= true
            uo.created_by = @user.id
            uo.save
            { message: "ok" }.to_json
          end

          app.get '/help-others/:id' do
            protected!
            check_identifier
            check_redirect
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

          app.get '/help-others/:id/specimens' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(params[:id])

            @page = (params[:page] || 1).to_i
            @total = @viewed_user.claims_received.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@viewed_user.claims_received, items: search_size, page: @page)
            haml :'help/specimens', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/ignored' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(params[:id])

            @page = (params[:page] || 1).to_i
            @total = @viewed_user.hidden_occurrences_by_others.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@viewed_user.hidden_occurrences_by_others, items: search_size, page: @page) 
            haml :'help/ignored', locals: { active_page: "help" }
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
              @viewed_user.update({ is_public: true, made_public: Time.now })
              @viewed_user.update_profile
              cache_clear "fragments/#{@viewed_user.identifier}"
              session[:made_public] = true
              twitter = ::Bloodhound::Twitter.new
              twitter.welcome_user(@viewed_user)
              redirect "/help-others/#{@viewed_user.identifier}"
            end
          end

          app.get '/help-others/:id/helpers.json' do
            protected!
            check_identifier
            viewed_user = find_user(params[:id])
            if !viewed_user
              halt 404, haml(:oops)
            end
            content_type "application/json", charset: 'utf-8'
            helpers = viewed_user.helped_by - [@user]
            { helpers: helpers }.to_json
          end

        end

      end
    end
  end
end
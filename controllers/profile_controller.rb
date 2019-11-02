# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module ProfileController

        def self.registered(app)

          app.before do
            set_session
          end

          #/auth/orcid is automatically added by OmniAuth
          app.get '/auth/orcid/callback' do
            session_data = request.env['omniauth.auth'].deep_symbolize_keys
            orcid = session_data[:uid]
            family = session_data[:info][:last_name] rescue nil
            given = session_data[:info][:first_name] rescue nil
            email = session_data[:info][:email] rescue nil
            other_names = session_data[:extra][:raw_info][:other_names].join("|") rescue nil
            country_code = session_data[:extra][:raw_info][:location]
            country = IsoCountryCodes.find(country_code).name rescue nil
            user = User.create_with(
                          family: family,
                          given: given,
                          orcid: session_data[:uid],
                          email: email,
                          other_names: other_names,
                          country: country,
                          country_code: country_code
                        )
                       .find_or_create_by(orcid: orcid)
            organization = user.current_organization.as_json.symbolize_keys rescue nil
            user.update(visited: Time.now)
            session[:omniauth] = OpenStruct.new({ id: user.id })
            cache_clear "fragments/#{user.identifier}"
            cache_clear "fragments/#{user.identifier}-trainer"
            redirect '/profile'
          end

          #/auth/zenodo is automatically added by OmniAuth
          app.get '/auth/zenodo/callback' do
            protected!
            session_data = request.env['omniauth.auth'].deep_symbolize_keys
            @user.zenodo_access_token = session_data[:info][:access_token_hash]
            @user.save
            session[:omniauth][:zenodo] = true
            redirect '/profile/settings'
          end

          app.delete '/auth/zenodo' do
            protected!
            @user.zenodo_access_token = nil
            @user.zenodo_doi = nil
            @user.zenodo_concept_doi = nil
            @user.save
            { message: "ok" }.to_json
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/profile' do
            protected!
            @total = {
              number_identified: @user.identified_count,
              number_recorded: @user.recorded_count,
              number_helped: @user.helped_count,
              number_claims_given: @user.claims_given.count,
              number_countries: @user.quick_country_counts,
              number_specimens_cited: @user.cited_specimens.count,
              number_articles: @user.cited_specimens.select(:article_id).distinct.count
            }
            haml :'profile/overview'
          end

          app.post '/profile/image' do
            protected!
            file_name = upload_image(app.root)
            if file_name
              @user.image_url = file_name
              @user.save
              cache_clear "fragments/#{@user.identifier}"
              cache_clear "fragments/#{@user.identifier}-trainer"
              { message: "ok" }.to_json
            else
              { message: "failed" }.to_json
            end
          end

          app.delete '/profile/image' do
            protected!
            if @user.image_url
              FileUtils.rm(File.join(app.root, "public", "images", "users", @user.image_url)) rescue nil
            end
            @user.image_url = nil
            @user.save
            cache_clear "fragments/#{@user.identifier}"
            cache_clear "fragments/#{@user.identifier}-trainer"
            { message: "ok" }.to_json
          end

          app.get '/profile/settings' do
            protected!
            haml :'profile/settings'
          end

          app.get '/profile/specimens' do
            protected!

            @page = (params[:page] || 1).to_i
            @total = @user.visible_occurrences.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@user.visible_occurrences.order("occurrences.typeStatus desc"), items: search_size, page: @page)
            haml :'profile/specimens'
          end

          app.get '/profile/support' do
            protected!

            @page = (params[:page] || 1).to_i
            @total = @user.claims_received.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@user.claims_received, items: search_size, page: @page)
            haml :'profile/support'
          end

          app.put '/profile/visibility.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            @user.is_public = req[:is_public]
            if req[:is_public]
              @user.made_public = Time.now
              twitter = ::Bloodhound::Twitter.new
              twitter.welcome_user(@user)
            end
            @user.save
            @user.update_profile
            cache_clear "fragments/#{@user.identifier}"
            { message: "ok"}.to_json
          end

          app.put '/profile/email_notification.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            @user.wants_mail = req[:wants_mail]
            @user.save
            { message: "ok"}.to_json
          end

          app.get '/profile/download.json' do
            protected!
            attachment "#{@user.orcid}.json"
            cache_control :no_cache
            headers.delete("Content-Length")
            content_type "application/ld+json", charset: 'utf-8'
            ::Bloodhound::IO.jsonld_stream(@user)
          end

          app.get '/profile/download.csv' do
            protected!
            records = @user.visible_occurrences
            csv_stream_headers(@user.orcid)
            body ::Bloodhound::IO.csv_stream_occurrences(records)
          end

          app.get '/profile/candidate-count.json' do
            protected!
            content_type "application/json"
            return { count: 0}.to_json if @user.family.nil?

            agent_ids = candidate_agents(@user).map{|a| a[:id] }.compact
            count = occurrences_by_agent_ids(agent_ids)
                      .where.not(occurrence_id: @user.user_occurrences.select(:occurrence_id))
                      .pluck(:occurrence_id)
                      .uniq
                      .count
            { count: count }.to_json
          end

          app.get '/profile/candidates.csv' do
            protected!
            agent_ids = candidate_agents(@user).pluck(:id)
            records = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @user.user_occurrences.select(:occurrence_id)).limit(5_000)
            csv_stream_headers("bloodhound-candidates")
            body ::Bloodhound::IO.csv_stream_candidates(records)
          end

          app.get '/profile/candidates' do
            protected!

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            if @user.family.nil?
              @results = []
              @total = nil
            else
              id_scores = candidate_agents(@user).map{|a| { id: a[:id], score: a[:score] } }.compact

              if !id_scores.empty?
                ids = id_scores.map{|a| a[:id]}
                nodes = AgentNode.where(agent_id: ids)
                if !nodes.empty?
                  (nodes.map(&:agent_id) - ids).each do |id|
                    id_scores << { id: id, score: 1 } #TODO: how to more effectively use the edge weights here?
                  end
                end
                occurrence_ids = occurrences_by_score(id_scores, @user)
              end

              specimen_pager(occurrence_ids.uniq)
            end

            haml :'profile/candidates'
          end

          app.get '/profile/candidates/agent/:id' do
            protected!

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            @searched_user = Agent.find(params[:id])
            id_scores = [{ id: @searched_user.id, score: 3 }]

            node = AgentNode.find_by(agent_id: @searched_user.id)
            if !node.nil?
              id_scores.concat(node.agent_nodes_weights.map{|a| { id: a[0], score: a[1] }})
            end

            occurrence_ids = occurrences_by_score(id_scores, @user)
            specimen_pager(occurrence_ids.uniq)

            haml :'profile/candidates'
          end

          app.post '/profile/upload-claims' do
            protected!
            begin
              upload_file(user_id: @user.id, created_by: @user.id)
            rescue => e
              flash.now[:error] = e.message
            end
            haml :'profile/upload'
          end

          app.get '/profile/ignored' do
            protected!

            @page = (params[:page] || 1).to_i
            @total = @user.hidden_occurrences.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@user.hidden_occurrences, items: search_size, page: @page)
            haml :'profile/ignored'
          end

          app.get '/profile/citations' do
            protected!
            page = (params[:page] || 1).to_i
            @pagy, @results = pagy(@user.articles_citing_specimens, page: page)
            haml :'profile/citations'
          end

          app.get '/profile/citation/:article_id' do
            protected!

            @article = Article.find(params[:article_id])
            if !@article
              halt 404
            end

            @page = (params[:page] || 1).to_i
            @total = @user.cited_specimens_by_article(@article.id).count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @pagy, @results = pagy(@user.cited_specimens_by_article(@article.id), items: search_size, page: @page)
            haml :'profile/citation'
          end

          app.get '/profile/refresh.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            @user.update_profile
            cache_clear "fragments/#{@user.identifier}"
            cache_clear "fragments/#{@user.identifier}-trainer"
            { message: "ok" }.to_json
          end

          app.delete '/profile/destroy' do
            protected!
            @user.destroy
            cache_clear "fragments/#{@user.identifier}"
            cache_clear "fragments/#{@user.identifier}-trainer"
            session.clear
            redirect '/'
          end

        end

      end
    end
  end
end
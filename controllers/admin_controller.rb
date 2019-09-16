# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module AdminController

        def self.registered(app)

          app.get '/admin' do
            admin_protected!
            haml :'admin/welcome', locals: { active_page: "administration" }
          end

          app.get '/admin/articles' do
            admin_protected!
            articles
            haml :'admin/articles', locals: { active_page: "administration" }
          end

          app.get '/admin/article/:id' do
            admin_protected!
            @article = Article.find(params[:id])
            haml :'admin/article', locals: { active_page: "administration" }
          end

          app.get '/admin/organizations' do
            admin_protected!
            sort = params[:sort] || nil
            order = params[:order] || nil
            organizations
            haml :'admin/organizations', locals: { active_page: "administration", sort: sort, order: order  }
          end

          app.get '/admin/organizations/search' do
            admin_protected!
            search_organization
            haml :'admin/organizations_search', locals: { active_page: "administration" }
          end

          app.get '/admin/organization/refresh.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'

            organization = Organization.find(params[:organization_id])
            organization.update_wikidata
            { message: "ok" }.to_json
          end

          app.get '/admin/organization/:id' do
            admin_protected!
            @organization = Organization.find(params[:id])
            haml :'admin/organization', locals: { active_page: "administration" }
          end

          app.post '/admin/organization/:id' do
            admin_protected!
            @organization = Organization.find(params[:id])
            name = params[:name].blank? ? nil : params[:name]
            address = params[:address].blank? ? nil : params[:address]
            isni = params[:isni].blank? ? nil : params[:isni]
            grid = params[:grid].blank? ? nil : params[:grid]
            ringgold = params[:ringgold].blank? ? nil : params[:ringgold]
            wikidata = params[:wikidata].blank? ? nil : params[:wikidata]
            institution_codes = params[:institution_codes].empty? ? nil : params[:institution_codes].split("|").map(&:strip)
            data = {
              name: name,
              address: address,
              isni: isni,
              grid: grid,
              ringgold: ringgold,
              wikidata: wikidata,
              institution_codes: institution_codes
            }
            wikidata_lib = ::Bloodhound::WikidataSearch.new
            code = wikidata || grid || ringgold
            wiki = wikidata_lib.institution_wikidata(code)
            data.merge!(wiki) if wiki 
            @organization.update(data)
            redirect "/admin/organization/#{params[:id]}"
          end

          app.delete '/admin/organization/:id' do
            admin_protected!
            organization = Organization.find(params[:id])
            organization.destroy
            redirect "/admin/organizations"
          end

          app.get '/admin/users' do
            admin_protected!
            sort = params[:sort] || nil
            order = params[:order] || nil
            admin_roster
            haml :'admin/roster', locals: { active_page: "administration", sort: sort, order: order }
          end

          app.get '/admin/users/helped' do
            admin_protected!
            latest_claims("living")
            haml :'admin/user_helped', locals: { active_page: "administration", active_tab: "orcid" }
          end

          app.get '/admin/users/helped/wikidata' do
            admin_protected!
            latest_claims("deceased")
            haml :'admin/user_helped', locals: { active_page: "administration", active_tab: "wikidata" }
          end

          app.get '/admin/users/search' do
            admin_protected!
            search_user
            haml :'admin/user_search', locals: { active_page: "administration" }
          end

          app.get '/admin/users/manage' do
            admin_protected!
            @new_user = session[:new_user]
            session[:new_user] = nil
            haml :'admin/manage_users', locals: { active_page: "administration" }
          end

          app.post '/admin/user/add' do
            admin_protected!
            create_user
            redirect '/admin/users/manage'
          end

          app.get '/admin/user/:id' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @total = {
              number_identified: @admin_user.identified_count,
              number_recorded: @admin_user.recorded_count,
              number_helped: @admin_user.helped_count,
              number_claims_given: @admin_user.claims_given.count,
              number_countries: @admin_user.quick_country_counts,
              number_specimens_cited: @admin_user.cited_specimens.count,
              number_articles: @admin_user.cited_specimens.select(:article_id).distinct.count
            }
            haml :'admin/overview', locals: { active_page: "administration" }
          end

          app.delete '/admin/user/:id' do
            admin_protected!
            @admin_user = User.find(params[:id])
            @admin_user.destroy
            cache_clear "fragments/#{@admin_user.identifier}"
            cache_clear "fragments/#{@admin_user.identifier}-trainer"
            redirect '/admin/users'
          end

          app.post '/admin/user/:id/image' do
            admin_protected!
            @admin_user = find_user(params[:id])
            file_name = upload_image
            if file_name
              @admin_user.image_url = file_name
              @admin_user.save
              { message: "ok" }.to_json
            else
              { message: "failed" }.to_json
            end
          end

          app.delete '/admin/user/:id/image' do
            admin_protected!
            @admin_user = find_user(params[:id])
            if @admin_user.image_url
              FileUtils.rm(File.join(root, "public", "images", "users", @admin_user.image_url)) rescue nil
            end
            @admin_user.image_url = nil
            @admin_user.save
            { message: "ok" }.to_json
          end

          app.get '/admin/user/:id/settings' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            haml :'admin/settings', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/specimens' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @page = (params[:page] || 1).to_i
            @total = @admin_user.visible_occurrences.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@admin_user.visible_occurrences.order("occurrences.typeStatus desc"), items: search_size, page: @page)
            haml :'admin/specimens', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/specimens.json' do
            admin_protected!
            admin_user = find_user(params[:id])
            attachment "#{admin_user.identifier}.json"
            cache_control :no_cache
            headers.delete("Content-Length")
            content_type "application/ld+json", charset: 'utf-8'
            ::Bloodhound::IO.jsonld_stream(admin_user)
          end

          app.get '/admin/user/:id/specimens.csv' do
            admin_protected!
            admin_user = find_user(params[:id])
            records = admin_user.visible_occurrences
            csv_stream_headers
            body ::Bloodhound::IO.csv_stream_occurrences(records)
          end

          app.get '/admin/user/:id/support' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])

            @page = (params[:page] || 1).to_i
            @total = @admin_user.claims_received.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@admin_user.claims_received, items: search_size, page: @page)
            haml :'admin/support', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/candidates.csv' do
            protected!
            @admin_user = find_user(params[:id])
            agent_ids = candidate_agents(@admin_user).pluck(:id)
            records = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @admin_user.user_occurrences.select(:occurrence_id))
            csv_stream_headers
            body ::Bloodhound::IO.csv_stream_candidates(records)
          end

          app.get '/admin/user/:id/candidates' do
            admin_protected!
            check_redirect
            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            @admin_user = find_user(params[:id])

            if @admin_user.family.nil?
              @results = []
              @total = nil
            else
              id_scores = candidate_agents(@admin_user).map{|a| { id: a[:id], score: a[:score] } }
                                                       .compact
              if !id_scores.empty?
                ids = id_scores.map{|a| a[:id]}
                nodes = AgentNode.where(agent_id: ids)
                if !nodes.empty?
                  (nodes.map(&:agent_id) - ids).each do |id|
                    id_scores << { id: id, score: 1 }
                  end
                end
                occurrence_ids = occurrences_by_score(id_scores, @admin_user)
              end

              specimen_pager(occurrence_ids)
            end

            haml :'admin/candidates', locals: { active_page: "administration" }
          end

          app.post '/admin/user/:id/upload-claims' do
            admin_protected!
            @admin_user = find_user(params[:id])
            begin
              upload_file(user_id: @admin_user.id, created_by: @user.id)
            rescue => e
              @error = e.message
            end
            haml :'admin/upload'
          end

          app.get '/admin/candidate-count.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            user = User.find(params[:user_id].to_i)
            return { count: 0 }.to_json if user.family.nil?

            agent_ids = candidate_agents(user).pluck(:id)
            count = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: user.user_occurrences.select(:occurrence_id)).count
            { count: count }.to_json
          end

          app.get '/admin/user/:id/candidates/agent/:agent_id' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            @searched_user = Agent.find(params[:agent_id])
            id_scores = [{ id: @searched_user.id, score: 3 }]

            node = AgentNode.find_by(agent_id: @searched_user.id)
            if !node.nil?
              id_scores.concat(node.agent_nodes_weights.map{|a| { id: a[0], score: a[1] }})
            end

            occurrence_ids = occurrences_by_score(id_scores, @admin_user)
            specimen_pager(occurrence_ids)

            haml :'admin/candidates', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/ignored' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @page = (params[:page] || 1).to_i
            @total = @admin_user.hidden_occurrences.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@admin_user.hidden_occurrences, items: search_size, page: @page)
            haml :'admin/ignored', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/citations' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            page = (params[:page] || 1).to_i
            @total = @admin_user.articles_citing_specimens.count

            @pagy, @results = pagy(@admin_user.articles_citing_specimens, page: page)
            haml :'admin/citations', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/citation/:article_id' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @article = Article.find(params[:article_id])
            if !@article
              halt 404, haml(:oops)
            end

            @page = (params[:page] || 1).to_i
            @total = @admin_user.cited_specimens_by_article(@article.id).count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@admin_user.cited_specimens_by_article(@article.id), page: @page, items: search_size)
            haml :'admin/citation', locals: { active_page: "administration" }
          end

          app.post '/admin/user-occurrence/bulk.json' do
            admin_protected!
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
                user_id: req[:user_id].to_i,
                occurrence_id: o.to_i,
                created_by: @user.id,
                action: action,
                visible: visible
              }
            }
            UserOccurrence.import data, batch_size: 250, validate: false, on_duplicate_key_ignore: true
            { message: "ok" }.to_json
          end

          app.post '/admin/user-occurrence/:occurrence_id.json' do
            admin_protected!
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

          app.put '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            occurrence_ids = req[:occurrence_ids].split(",")
            visible = req[:visible] rescue true
            data = { action: req[:action], visible: visible, created_by: @user.id }
            UserOccurrence.where(id: occurrence_ids, user_id: req[:user_id].to_i)
                          .update_all(data)
            { message: "ok" }.to_json
          end

          app.put '/admin/user-occurrence/:id.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find_by(id: params[:id].to_i, user_id: req[:user_id].to_i)
            uo.action = req[:action]
            uo.visible = true
            uo.created_by = @user.id
            uo.save
            { message: "ok" }.to_json
          end

          app.delete '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            ids = req[:ids].split(",")
            UserOccurrence.where(id: ids, user_id: req[:user_id].to_i)
                          .delete_all
            { message: "ok" }.to_json
          end

          app.delete '/admin/user-occurrence/:id.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            UserOccurrence.where(id: params[:id].to_i, user_id: req[:user_id].to_i)
                          .delete_all
            { message: "ok" }.to_json
          end

          app.get '/admin/refresh.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            admin_user = User.find(params[:user_id].to_i)
            admin_user.update_profile
            cache_clear "fragments/#{admin_user.identifier}"
            cache_clear "fragments/#{admin_user.identifier}-trainer"
            { message: "ok" }.to_json
          end

          app.put '/admin/visibility.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            admin_user = User.find(params[:user_id].to_i)
            admin_user.is_public = req[:is_public]
            if req[:is_public]
              admin_user.made_public = Time.now
              twitter = ::Bloodhound::Twitter.new
              twitter.welcome_user(admin_user)
            end
            admin_user.save
            admin_user.update_profile
            cache_clear "fragments/#{admin_user.identifier}"
            { message: "ok" }.to_json
          end

        end

      end
    end
  end
end
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

          app.get '/admin/users' do
            admin_protected!
            @new_user = session[:new_user]
            session[:new_user] = nil
            admin_roster
            haml :'admin/roster', locals: { active_page: "administration" }
          end

          app.post '/admin/user/add' do
            admin_protected!
            if params[:orcid] && params[:orcid].is_orcid?
              new_user = User.find_or_create_by({ orcid: params[:orcid] })
              new_user.update_orcid_profile
              session[:new_user] = { fullname: new_user.fullname, orcid: new_user.orcid }
            end
            redirect '/admin/users'
          end

          app.get '/admin/user/:orcid' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])
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

          app.get '/admin/user/:orcid/specimens' do
            admin_protected!
            if params[:orcid].is_orcid?
              @admin_user = User.find_by_orcid(params[:orcid])
              @page = (params[:page] || 1).to_i
              @total = @admin_user.visible_occurrences.count

              if @page*search_size > @total
                @page = @total/search_size.to_i + 1
              end

              @results = @admin_user.visible_occurrences
                                    .order("occurrences.typeStatus desc")
                                    .paginate(page: @page, per_page: search_size)
              haml :'admin/specimens', locals: { active_page: "administration" }
            else
              status 404
              haml :oops
            end

          end

          app.get '/admin/user/:orcid/specimens.json' do
            admin_protected!
            if params[:orcid].is_orcid?
              content_type "application/ld+json", charset: 'utf-8'
              begin
                user = User.find_by_orcid(params[:orcid])
                dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| column == 'gbifID'}
                                            .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if o != "gbifID" }]
                {
                  "@context": {
                    "@vocab": "http://schema.org/",
                    identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                    recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                    Occurrence: "http://rs.tdwg.org/dwc/terms/Occurrence"
                  }.merge(dwc_contexts),
                  "@type": "Person",
                  "@id": "https://orcid.org/#{user.orcid}",
                  givenName: user.given,
                  familyName: user.family,
                  alternateName: user.other_names.split("|"),
                  "@reverse": {
                    identified: user.identifications_enum,
                    recorded: user.recordings_enum
                  }
                }.to_json
              rescue
                status 404
                {}.to_json
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/admin/user/:orcid/specimens.csv' do
            admin_protected!
            if params[:orcid].is_orcid?
              user = User.find_by_orcid(params[:orcid])
              records = user.visible_occurrences
              csv_stream_headers
              body csv_stream_occurrences(records)
            else
              status 404
              haml :oops
            end
          end

          app.get '/admin/user/:orcid/support' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])

            @page = (params[:page] || 1).to_i
            @total = @admin_user.claims_received.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @results = @admin_user.claims_received
                                  .paginate(page: @page, per_page: search_size)
            haml :'admin/support', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:orcid/candidates' do
            admin_protected!
            occurrence_ids = []
            if params[:orcid].is_orcid?
              @page = (params[:page] || 1).to_i

              @admin_user = User.find_by_orcid(params[:orcid])

              if @admin_user.family.nil?
                @results = []
                @total = nil
              else
                agents = search_agents(@admin_user.family, @admin_user.given)

                if !@admin_user.other_names.nil?
                  @admin_user.other_names.split("|").each do |other_name|
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

                id_scores = agents.compact.uniq
                                          .map{|a| { id: a[:id], score: a[:score] } }
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
            else
              status 404
              haml :oops
            end

          end

          app.get '/admin/candidate-count.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            @admin_user = User.find(params[:user_id].to_i)
            return { count: 0}.to_json if @admin_user.family.nil?

            agents = search_agents(@admin_user.family, @admin_user.given)
            if !@admin_user.other_names.nil?
              @admin_user.other_names.split("|").each do |other_name|
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
            agent_ids = agents.compact.uniq.pluck(:id)
            count = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @admin_user.user_occurrences.select(:occurrence_id)).count
            { count: count }.to_json
          end

          app.get '/admin/user/:orcid/candidates/agent/:id' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            @searched_user = Agent.find(params[:id])
            id_scores = [{ id: @searched_user.id, score: 3 }]

            node = AgentNode.find_by(agent_id: @searched_user.id)
            if !node.nil?
              id_scores.concat(node.agent_nodes_weights.map{|a| { id: a[0], score: a[1] }})
            end

            occurrence_ids = occurrences_by_score(id_scores, @admin_user)
            specimen_pager(occurrence_ids)

            haml :'admin/candidates', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:orcid/ignored' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])
            @page = (params[:page] || 1).to_i
            @total = @admin_user.hidden_occurrences.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @results = @admin_user.hidden_occurrences
                                  .paginate(page: @page, per_page: search_size)
            haml :'admin/ignored', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:orcid/citations' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])
            page = (params[:page] || 1).to_i
            @total = @admin_user.articles_citing_specimens.count
            @results = @admin_user.articles_citing_specimens
                                  .paginate(page: page)
            haml :'admin/citations', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:orcid/citation/:article_id' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])
            @article = Article.find(params[:article_id])
            if @article
              @page = (params[:page] || 1).to_i
              @total = @admin_user.cited_specimens_by_article(@article.id).count

              if @page*search_size > @total
                @page = @total/search_size.to_i + 1
              end

              @results = @admin_user.cited_specimens_by_article(@article.id)
                                    .paginate(page: @page, per_page: search_size)
              haml :'admin/citation', locals: { active_page: "administration" }
            else
              status 404
              haml :oops
            end
          end

          app.post '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            occurrence_ids = req[:occurrence_ids].split(",")
            UserOccurrence.transaction do
              if !visible
                UserOccurrence.where(occurrence_id: occurrence_ids)
                              .where(user_id: req[:user_id].to_i)
                              .destroy_all
              end
              data = occurrence_ids.map{|o| { 
                  user_id: req[:user_id].to_i,
                  occurrence_id: o.to_i,
                  created_by: @user[:id],
                  action: action,
                  visible: visible
                }
              }
              UserOccurrence.import data, batch_size: 100, validate: false
            end
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
            uo.created_by = @user[:id].to_i
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
            UserOccurrence.where(id: occurrence_ids, user_id: req[:user_id].to_i)
                          .update_all({action: req[:action]})
            { message: "ok" }.to_json
          end

          app.put '/admin/user-occurrence/:id.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find_by(id: params[:id].to_i, user_id: req[:user_id].to_i)
            uo.action = req[:action]
            uo.visible = true
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

          app.get '/admin/orcid-refresh.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            user = User.find(params[:user_id].to_i)
            user.update_orcid_profile
            cache_clear "fragments/#{user.orcid}"
            { message: "ok" }.to_json
          end

          app.put '/admin/visibility.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            user = User.find(params[:user_id].to_i)
            user.is_public = req[:is_public]
            if req[:is_public]
              user.made_public = Time.now
            end
            user.save
            user.update_orcid_profile
            cache_clear "fragments/#{user.orcid}"
            { message: "ok" }.to_json
          end

        end

      end
    end
  end
end
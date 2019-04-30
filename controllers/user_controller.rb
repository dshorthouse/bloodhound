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
            redirect '/profile'
          end

          #/auth/zenodo is automatically added by OmniAuth
          app.get '/auth/zenodo/callback' do
            protected!
            session_data = request.env['omniauth.auth'].deep_symbolize_keys
            @user.zenodo_access_token = session_data[:info][:access_token_hash]
            @user.save
            session[:omniauth][:zenodo] = true
            redirect '/profile'
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
            file_name = upload_image
            if file_name
              @user.image_url = file_name
              @user.save
              { message: "ok" }.to_json
            else
              { message: "failed" }.to_json
            end
          end

          app.delete '/profile/image' do
            protected!
            if @user.image_url
              FileUtils.rm(File.join(root, "public", "images", "users", @user.image_url))
            end
            @user.image_url = nil
            @user.save
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
            end
            @user.save
            cache_clear "fragments/#{@user.identifier}"
            { message: "ok"}.to_json
          end

          app.get '/profile/download.json' do
            protected!
            content_type "application/ld+json", charset: 'utf-8'
            ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
            dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| ignore_cols.include?(column)}
                                        .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignore_cols.include?(o) }]
            {
              "@context": {
                "@vocab": "http://schema.org/",
                identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen"
              }.merge(dwc_contexts),
              "@type": "Person",
              "@id": "https://orcid.org/#{@user.orcid}",
              sameAs: "https://orcid.org/#{@user.orcid}",
              givenName: @user.given,
              familyName: @user.family,
              alternateName: @user.other_names.split("|"),
              "@reverse": {
                identified: @user.identifications
                                       .map{|o| {
                                           "@type": "PreservedSpecimen",
                                           "@id": "https://gbif.org/occurrence/#{o.occurrence.id}",
                                           sameAs: "https://gbif.org/occurrence/#{o.occurrence.id}"
                                         }.merge(o.occurrence.attributes.reject {|column| ignore_cols.include?(column) })
                                       },
                recorded: @user.recordings
                                       .map{|o| {
                                           "@type": "PreservedSpecimen",
                                           "@id": "https://gbif.org/occurrence/#{o.occurrence.id}",
                                           sameAs: "https://gbif.org/occurrence/#{o.occurrence.id}"
                                         }.merge(o.occurrence.attributes.reject {|column| ignore_cols.include?(column) })
                                       }
              }
            }.to_json
          end

          app.get '/profile/download.csv' do
            protected!
            records = @user.visible_occurrences
            csv_stream_headers
            body csv_stream_occurrences(records)
          end

          app.get '/profile/candidate-count.json' do
            protected!
            content_type "application/json"
            return { count: 0}.to_json if @user.family.nil?

            agent_ids = candidate_agents(@user).map{|a| a[:id] if a[:score] >= 10 }.compact
            count = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @user.user_occurrences.select(:occurrence_id))
                                                       .count
            { count: count }.to_json
          end

          app.get '/profile/candidates.csv' do
            protected!
            agent_ids = candidate_agents(@user).pluck(:id)
            records = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @user.user_occurrences.select(:occurrence_id)).limit(5_000)
            csv_stream_headers("bloodhound-candidates")
            body csv_stream_candidates(records)
          end

          app.get '/profile/candidates' do
            protected!

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            if @user.family.nil?
              @results = []
              @total = nil
            else
              id_scores = candidate_agents(@user).map{|a| { id: a[:id], score: a[:score] } if a[:score] >= 10 }.compact

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

              specimen_pager(occurrence_ids)
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
            specimen_pager(occurrence_ids)

            haml :'profile/candidates'
          end

          app.post '/profile/upload-claims' do
            protected!
            upload_file(user_id: @user.id, created_by: @user.id)
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
            @total = @user.articles_citing_specimens.count
            @pagy, @results = pagy(@user.articles_citing_specimens, page: page)
            haml :'profile/citations'
          end

          app.get '/profile/citation/:article_id' do
            protected!

            @article = Article.find(params[:article_id])
            if @article
              @page = (params[:page] || 1).to_i
              @total = @user.cited_specimens_by_article(@article.id).count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end

              @pagy, @results = pagy(@user.cited_specimens_by_article(@article.id), items: search_size, page: @page)
              haml :'profile/citation'
            else
              status 404
              haml :oops
            end
          end

          app.get '/profile/refresh.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            @user.update_profile
            cache_clear "fragments/#{@user.identifier}"
            { message: "ok" }.to_json
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/help-others' do
            protected!
            @results = []
            @countries = IsoCountryCodes.for_select.group_by{|u| ActiveSupport::Inflector.transliterate(u[0][0]) }
            if params[:q]
              search_user
            end
            haml :'help/others', locals: { active_page: "help" }
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

            if params[:id].is_orcid? || params[:id].is_wiki_id?
              occurrence_ids = []
              @page = (params[:page] || 1).to_i

              @viewed_user = find_user(params[:id])

              if @viewed_user == @user
                redirect "/profile/candidates"
              end

              if @viewed_user.family.nil?
                @results = []
                @total = nil
              else
                id_scores = candidate_agents(@viewed_user).map{|a| { id: a[:id], score: a[:score] } if a[:score] >= 10 }.compact
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
            else
              status 404
              haml :oops
            end
          end

          app.get '/help-others/:id/candidates.csv' do
            protected!
            csv_stream_headers
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              agent_ids = candidate_agents(@viewed_user).pluck(:id)
              records = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @viewed_user.user_occurrences.select(:occurrence_id)).limit(5_000)
              body csv_stream_candidates(records)
            else
              status 404
            end
          end

          app.post '/help-others/:id/upload-claims' do
            protected!
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              upload_file(user_id: @viewed_user.id, created_by: @user.id)
              haml :'help/upload', locals: { active_page: "help" }
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/specimens.json' do
            content_type "application/ld+json", charset: 'utf-8'
            ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              begin
                viewed_user = find_user(params[:id])
                id_url = viewed_user.orcid ? "https://orcid.org/#{viewed_user.orcid}" : "https://www.wikidata.org/wiki/#{viewed_user.wikidata}"
                dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| ignore_cols.include?(column)}
                                            .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignore_cols.include?(o) }]
                {
                  "@context": {
                    "@vocab": "http://schema.org/",
                    identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                    recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                    PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen"
                  }.merge(dwc_contexts),
                  "@type": "Person",
                  "@id": id_url,
                  givenName: viewed_user.given,
                  familyName: viewed_user.family,
                  alternateName: viewed_user.other_names.split("|"),
                  sameAs: id_url,
                  "@reverse": {
                    identified: viewed_user.identifications_enum,
                    recorded: viewed_user.recordings_enum
                  }
                }.to_json
              rescue
                status 404
                {}.to_json
              end
            else
              status 404
              {}.to_json
            end
          end

          app.get '/:id/specimens.csv' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              begin
                csv_stream_headers
                @viewed_user = find_user(params[:id])
                records = @viewed_user.visible_occurrences
                body csv_stream_occurrences(records)
              rescue
                status 404
              end
            else
              status 404
            end
          end

          app.get '/:id' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user
                @total = {
                  number_identified: @viewed_user.identified_count,
                  number_recorded: @viewed_user.recorded_count,
                  country_counts: @viewed_user.country_counts
                }
                haml :'public/overview', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/specialties' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user && @viewed_user.is_public?
                @families_identified = @viewed_user.identified_families
                @families_recorded = @viewed_user.recorded_families
                haml :'public/specialties', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/specimens' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.visible_occurrences.order("occurrences.typeStatus desc"), page: page)
                haml :'public/specimens', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/citations' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.articles_citing_specimens, page: page)
                haml :'public/citations', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/citation/:article_id' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              @article= Article.find(params[:article_id])
              if @article && @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.cited_specimens_by_article(@article.id), page: page)
                haml :'public/citation', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/co-collectors' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.recorded_with, page: page)
                haml :'public/co_collectors', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/identified-for' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.identified_for, page: page)
                haml :'public/identified_for', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/identifications-by' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.identified_by, page: page)
                haml :'public/identifications_by', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/deposited-at' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user && @viewed_user.is_public?
                @recordings_at = @viewed_user.recordings_deposited_at
                @identifications_at = @viewed_user.identifications_deposited_at
                haml :'public/deposited_at', locals: { active_page: "roster" }
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/comments' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              @viewed_user = find_user(params[:id])
              if @viewed_user.can_comment?
                haml :'public/comments', locals: { active_page: "roster"}
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:id/progress.json' do
            content_type "application/json"

            viewed_user = find_user(params[:id])
            claimed = viewed_user.all_occurrences_count
            agent_ids = candidate_agents(viewed_user).map{|a| a[:id] if a[:score] >= 10 }.compact
            unclaimed = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: viewed_user.user_occurrences.select(:occurrence_id))
                                                           .count
            { claimed: claimed, unclaimed: unclaimed }.to_json
          end

        end

      end
    end
  end
end
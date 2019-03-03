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
                          country: country
                        )
                       .find_or_create_by(orcid: orcid)
            organization = user.current_organization.as_json.symbolize_keys rescue nil
            user.update(visited: Time.now)
            user_hash = user.as_json.symbolize_keys
            user_hash[:fullname] = user.fullname
            user_hash[:current_organization] = organization
            session[:omniauth] = user_hash
            redirect '/profile'
          end

          app.get '/profile' do
            protected!
            user = User.find(@user[:id])
            @total = {
              number_identified: user.identified_count,
              number_recorded: user.recorded_count,
              number_helped: user.helped_count,
              number_claims_given: user.claims_given.count,
              number_countries: user.quick_country_counts,
              number_specimens_cited: user.cited_specimens.count,
              number_articles: user.cited_specimens.select(:article_id).distinct.count
            }
            cache_clear "fragments/#{user.identifier}"
            haml :'profile/overview'
          end

          app.get '/profile/specimens' do
            protected!
            user = User.find(@user[:id])

            @page = (params[:page] || 1).to_i
            @total = user.visible_occurrences.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @pagy, @results = pagy(user.visible_occurrences.order("occurrences.typeStatus desc"), items: search_size, page: @page)
            haml :'profile/specimens'
          end

          app.get '/profile/support' do
            protected!
            user = User.find(@user[:id])

            @page = (params[:page] || 1).to_i
            @total = user.claims_received.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @pagy, @results = pagy(ser.claims_received, items: search_size, page: @page)
            haml :'profile/support'
          end

          app.put '/profile/visibility.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            user = User.find(@user[:id])
            user.is_public = req[:is_public]
            if req[:is_public]
              user.made_public = Time.now
            end
            user.save
            update_session
            cache_clear "fragments/#{user.identifier}"
            { message: "ok"}.to_json
          end

          app.get '/profile/download.json' do
            protected!
            content_type "application/ld+json", charset: 'utf-8'
            user = User.find(@user[:id])
            dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| column == 'gbifID'}
                                        .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if o != "gbifID" }]
            {
              "@context": {
                "@vocab": "http://schema.org/",
                identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen"
              }.merge(dwc_contexts),
              "@type": "Person",
              "@id": "https://orcid.org/#{user.orcid}",
              sameAs: "https://orcid.org/#{user.orcid}",
              givenName: user.given,
              familyName: user.family,
              alternateName: user.other_names.split("|"),
              "@reverse": {
                identified: user.identifications
                                       .map{|o| {
                                           "@type": "PreservedSpecimen",
                                           "@id": "https://gbif.org/occurrence/#{o.occurrence.id}",
                                           sameAs: "https://gbif.org/occurrence/#{o.occurrence.id}"
                                         }.merge(o.occurrence.attributes.reject {|column| column == 'gbifID'})
                                       },
                recorded: user.recordings
                                       .map{|o| {
                                           "@type": "PreservedSpecimen",
                                           "@id": "https://gbif.org/occurrence/#{o.occurrence.id}",
                                           sameAs: "https://gbif.org/occurrence/#{o.occurrence.id}"
                                         }.merge(o.occurrence.attributes.reject {|column| column == 'gbifID'})
                                       }
              }
            }.to_json
          end

          app.get '/profile/download.csv' do
            protected!
            user = User.find(@user[:id])
            records = user.visible_occurrences
            csv_stream_headers
            body csv_stream_occurrences(records)
          end

          app.get '/profile/candidate-count.json' do
            protected!
            content_type "application/json"
            return { count: 0}.to_json if @user[:family].nil?

            user = User.find(@user[:id])
            agent_ids = candidate_agents.map{|a| a[:id] if a[:score] >= 10 }.compact
            count = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: user.user_occurrences.select(:occurrence_id))
                                                       .count
            { count: count }.to_json
          end

          app.get '/profile/candidates.csv' do
            protected!
            user = User.find(@user[:id])
            agent_ids = candidate_agents.pluck(:id)
            records = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: user.user_occurrences.select(:occurrence_id))
            csv_stream_headers("bloodhound-candidates")
            body csv_stream_candidates(records)
          end

          app.get '/profile/candidates' do
            protected!
            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            if @user[:family].nil?
              @results = []
              @total = nil
            else
              id_scores = candidate_agents.map{|a| { id: a[:id], score: a[:score] } if a[:score] >= 10 }.compact

              if !id_scores.empty?
                ids = id_scores.map{|a| a[:id]}
                nodes = AgentNode.where(agent_id: ids)
                if !nodes.empty?
                  (nodes.map(&:agent_id) - ids).each do |id|
                    id_scores << { id: id, score: 1 } #TODO: how to more effectively use the edge weights here?
                  end
                end
                occurrence_ids = occurrences_by_score(id_scores, User.find(@user[:id]))
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

            occurrence_ids = occurrences_by_score(id_scores, User.find(@user[:id]))
            specimen_pager(occurrence_ids)

            haml :'profile/candidates'
          end

          app.post '/profile/upload-claims' do
            protected!
            @error = nil
            @record_count = 0
            accepted_actions = ["identified","recorded","identified,recorded","recorded,identified"]
            if params[:file] && params[:file][:tempfile]
              tempfile = params[:file][:tempfile]
              filename = params[:file][:filename]
              if params[:file][:type] == "text/csv" && params[:file][:tempfile].size <= 5_000_000
                begin
                  items = []
                  CSV.foreach(tempfile, headers: true) do |row|
                    action = row["action"].gsub(/\s+/, "") rescue nil
                    next if action.blank?
                    if accepted_actions.include?(action) && row.include?("gbifID")
                      items << UserOccurrence.new({
                        occurrence_id: row["gbifID"],
                        user_id: @user[:id],
                        created_by: @user[:id],
                        action: action
                      })
                      @record_count += 1
                    end
                  end
                  UserOccurrence.import items, batch_size: 250, validate: false, on_duplicate_key_ignore: true
                  tempfile.unlink
                rescue
                  tempfile.unlink
                  @error = "There was an error in your file. Did it at least contain the headers, action and gbifID and were columns separated by commas?"
                end
              else
                tempfile.unlink
                @error = "Only files of type tex/csv less than 5MB are accepted."
              end
            else
              @error = "No file was uploaded."
            end
            haml :'profile/upload'
          end

          app.get '/profile/ignored' do
            protected!
            user = User.find(@user[:id])
            @page = (params[:page] || 1).to_i
            @total = user.hidden_occurrences.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @pagy, @results = pagy(user.hidden_occurrences, items: search_size, page: @page)
            haml :'profile/ignored'
          end

          app.get '/profile/citations' do
            protected!
            user = User.find(@user[:id])
            page = (params[:page] || 1).to_i
            @total = user.articles_citing_specimens.count
            @pagy, @results = pagy(user.articles_citing_specimens, page: page)
            haml :'profile/citations'
          end

          app.get '/profile/citation/:article_id' do
            protected!
            user = User.find(@user[:id])
            @article = Article.find(params[:article_id])
            if @article
              @page = (params[:page] || 1).to_i
              @total = user.cited_specimens_by_article(@article.id).count

              if @page*search_size > @total
                @page = @total/search_size.to_i + 1
              end

              @pagy, @results = pagy(user.cited_specimens_by_article(@article.id), items: search_size, page: @page)
              haml :'profile/citation'
            else
              status 404
              haml :oops
            end
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/help-users' do
            protected!
            @results = []
            if params[:q]
              search_user
            end
            haml :'help/users'
          end

          app.get '/help-user/:id' do
            protected!

            if params[:id].is_orcid? || params[:id].is_wiki_id?
              occurrence_ids = []
              @page = (params[:page] || 1).to_i

              @viewed_user = find_user(params[:id])
              current_user = User.find(@user[:id])

              if @viewed_user == current_user
                redirect "/profile/candidates"
              end

              if @viewed_user.family.nil?
                @results = []
                @total = nil
              else
                agents = search_agents(@viewed_user.family, @viewed_user.given)

                if !@viewed_user.other_names.nil?
                  @viewed_user.other_names.split("|").each do |other_name|
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

                if !params.has_key?(:relaxed) || params[:relaxed] == "0"
                  agents.delete_if do |key,value|
                    !@viewed_user.given.nil? && !key[:given].nil? && DwcAgent.similarity_score(key[:given], @viewed_user.given) == 0
                  end
                end

                id_scores = agents.compact.uniq
                                          .map{|a| { id: a[:id], score: a[:score] } if a[:score] >= 10}
                                          .compact

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

              haml :'help/user'
            else
              status 404
              haml :oops
            end
          end

          app.get '/profile/refresh.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            user = User.find(@user[:id])
            user.update_profile
            update_session
            cache_clear "fragments/#{user.identifier}"
            { message: "ok" }.to_json
          end

          app.get '/:id/specimens.json' do
            content_type "application/ld+json", charset: 'utf-8'
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              begin
                user = find_user(params[:id])
                id_url = user.orcid ? "https://orcid.org/#{user.orcid}" : "https://www.wikidata.org/wiki/#{user.wikidata}"
                dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| column == 'gbifID'}
                                            .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if o != "gbifID" }]
                {
                  "@context": {
                    "@vocab": "http://schema.org/",
                    identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                    recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                    PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen"
                  }.merge(dwc_contexts),
                  "@type": "Person",
                  "@id": id_url,
                  givenName: user.given,
                  familyName: user.family,
                  alternateName: user.other_names.split("|"),
                  sameAs: id_url,
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
              {}.to_json
            end
          end

          app.get '/:id/specimens.csv' do
            if params[:id].is_orcid? || params[:id].is_wiki_id?
              begin
                @viewed_user = find_user(params[:id])
                records = @viewed_user.visible_occurrences
                csv_stream_headers
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
              if @viewed_user && @viewed_user.is_public?
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
              haml :'public/comments', locals: { active_page: "roster"}
            else
              status 404
              haml :oops
            end
          end

        end

      end
    end
  end
end
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
            user.update(visited: Time.now)
            user_hash = user.as_json.symbolize_keys
            user_hash[:fullname] = user.fullname
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
              number_claims_given: user.claims_given.count
            }
            @helped = user.helped_counts.map{ |u,v| 
              helped_user = User.find(u)
              { 
                name: helped_user.fullname_reverse,
                orcid: helped_user.orcid,
                count: v
              }
            }
            haml :profile
          end

          app.get '/profile/specimens' do
            protected!
            user = User.find(@user[:id])

            @page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i
            @total = user.visible_occurrences.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @results = user.visible_occurrences
                           .paginate(page: @page, per_page: search_size)
            haml :profile_specimens
          end

          app.get '/profile/support' do
            protected!
            user = User.find(@user[:id])

            @page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i
            @total = user.claims_received.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @results = user.claims_received
                           .paginate(page: @page, per_page: search_size)
            haml :profile_support
          end

          app.put '/profile.json' do
            protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            user = User.find(@user[:id])
            user.is_public = req[:is_public]
            user.save
            update_session
            { message: "ok"}.to_json
          end

          app.get '/profile/download.json' do
            protected!
            content_type "application/json"
            current_user = User.find(@user[:id])
            user = {}
            user[:personal] = current_user
            user[:occurrences] = current_user.visible_occurrences
                                             .map{|o| { action: o.action }.merge(o.occurrence.as_json) }
            user.to_json
          end

          app.get '/profile/download.csv' do
            protected!
            content_type "application/csv"
            attachment   "download.csv"
            user = User.find(@user[:id])
            records = user.visible_occurrences
            CSV.generate do |csv|
              csv << ["action"].concat(Occurrence.attribute_names)
              records.each { |r| csv << [r.action].concat(r.occurrence.attributes.values) }
            end
          end

          app.get '/profile/candidates' do
            protected!
            occurrence_ids = []
            @page = (params[:page] || 1).to_i
            @search_size = (params[:per] || 25).to_i

            if @user[:family].nil?
              @results = []
              @total = nil
            else
              agents = search_agents(@user[:family], @user[:given])

              if !@user[:other_names].nil?
                @user[:other_names].split("|").each do |other_name|
                  parsed = Namae.parse other_name.gsub(/\./, ".\s")
                  name = DwcAgent.clean(parsed[0])
                  family = !name[:family].nil? ? name[:family] : nil
                  given = !name[:given].nil? ? name[:given] : nil
                  if !family.nil?
                    agents.concat search_agents(family, given)
                  end
                end
              end

              id_scores = agents.compact.uniq
                                        .map{|a| { id: a[:id], score: a[:score] }}

              if !id_scores.empty?
                ids = id_scores.map{|a| a[:id]}
                nodes = AgentNode.where(agent_id: ids)
                if !nodes.empty?
                  (nodes.map(&:agent_id) - ids).each do |id|
                    id_scores << { id: id, score: 1 } #TODO: how to more effectively use the edge weights here?
                  end
                end
                occurrence_ids = occurrences_by_score(id_scores)
              end

              specimen_pager(occurrence_ids)
            end

            haml :profile_candidates
          end

          app.get '/profile/candidates/agent/:id' do
            protected!
            occurrence_ids = []
            @page = (params[:page] || 1).to_i
            @search_size = (params[:per] || 25).to_i

            @searched_user = Agent.find(params[:id])
            id_scores = [{ id: @searched_user.id, score: 3 }]

            node = AgentNode.find_by(agent_id: @searched_user.id)
            if !node.nil?
              id_scores.concat(node.agent_nodes_weights.map{|a| { id: a[0], score: a[1] }})
            end

            occurrence_ids = occurrences_by_score(id_scores)
            specimen_pager(occurrence_ids)

            haml :profile_candidates
          end

          app.get '/profile/ignored' do
            protected!
            user = User.find(@user[:id])
            @page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i
            @total = user.hidden_occurrences.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @results = user.hidden_occurrences
                           .paginate(page: @page, per_page: search_size)
            haml :profile_ignored
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/help-users' do
            protected!
            haml :help_users
          end

          app.get '/help-user/:orcid' do
            protected!

            if params[:orcid].is_orcid?
              occurrence_ids = []
              @page = (params[:page] || 1).to_i
              @search_size = (params[:per] || 25).to_i

              @help_user = User.find_by_orcid(params[:orcid])
              current_user = User.find(@user[:id])

              if @help_user == current_user
                redirect "/profile/candidates"
              end

              if @help_user.family.nil?
                @results = []
                @total = nil
              else
                agents = search_agents(@help_user.family, @help_user.given)

                if !@help_user.other_names.nil?
                  @help_user.other_names.split("|").each do |other_name|
                    parsed = Namae.parse other_name.gsub(/\./, ".\s")
                    name = DwcAgent.clean(parsed[0])
                    family = !name[:family].nil? ? name[:family] : ""
                    given = !name[:given].nil? ? name[:given] : ""
                    if !family.blank?
                      agents.concat search_agents(family, given)
                    end
                  end
                end

                id_scores = agents.compact.uniq
                                          .map{|a| { id: a[:id], score: a[:score] }}

                if !id_scores.empty?
                  ids = id_scores.map{|a| a[:id]}
                  nodes = AgentNode.where(agent_id: ids)
                  if !nodes.empty?
                    (nodes.map(&:agent_id) - ids).each do |id|
                      id_scores << { id: id, score: 1 } #TODO: how to more effectively use the edge weights here?
                    end
                  end
                  occurrence_ids = occurrences_by_score(id_scores, @help_user.id)
                end

                specimen_pager(occurrence_ids)
              end

              haml :help_user
            else
              status 404
              haml :oops
            end
          end

          app.get '/orcid-refresh.json' do
            protected!
            content_type "application/json"
            user = User.find(@user[:id])
            user.update_orcid_profile
            update_session
            { message: "ok" }.to_json
          end

          app.get '/:orcid/specimens.json' do
            if params[:orcid].is_orcid?
              content_type "application/json"
              @viewed_user = User.find_by_orcid(params[:orcid])
              user = {}
              user[:personal] = @viewed_user
              user[:occurrences] = @viewed_user.visible_occurrences
                                               .map{|o| { action: o.action }.merge(o.occurrence.as_json) }
              user.to_json
            else
              status 404
              haml :oops
            end
          end

          app.get '/:orcid/specimens.csv' do
            if params[:orcid].is_orcid?
              content_type "application/csv"
              attachment   "#{params[:orcid]}.csv"
              @viewed_user = User.find_by_orcid(params[:orcid])
              records = @viewed_user.visible_occurrences
              CSV.generate do |csv|
                csv << ["action"].concat(Occurrence.attribute_names)
                records.each { |r| csv << [r.action].concat(r.occurrence.attributes.values) }
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:orcid' do
            if params[:orcid].is_orcid?
              @viewed_user = User.find_by_orcid(params[:orcid])
              if @viewed_user && @viewed_user.is_public?
                @total = {
                  number_identified: @viewed_user.identified_count,
                  number_recorded: @viewed_user.recorded_count,
                  number_helped: @viewed_user.helped_count,
                  number_claims_given: @viewed_user.claims_given.count
                }
                @country_counts = @viewed_user.country_counts
                haml :user
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:orcid/specialties' do
            if params[:orcid].is_orcid?
              @viewed_user = User.find_by_orcid(params[:orcid])
              if @viewed_user && @viewed_user.is_public?
                @total = {
                  number_identified: @viewed_user.identified_count,
                  number_recorded: @viewed_user.recorded_count,
                  number_helped: @viewed_user.helped_count,
                  number_claims_given: @viewed_user.claims_given.count
                }
                @families_identified = @viewed_user.identified_families
                @families_recorded = @viewed_user.recorded_families
                haml :user_specialties
              else
                status 404
                haml :oops
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/:orcid/specimens' do
            if params[:orcid].is_orcid?
              @viewed_user = User.find_by_orcid(params[:orcid])
              if @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @results = @viewed_user.visible_occurrences
                                       .paginate(page: params[:page])

                haml :user_specimens
              else
                status 404
                haml :oops
              end
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
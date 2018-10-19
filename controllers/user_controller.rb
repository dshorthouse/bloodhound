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

            @page = (params[:page] || 1).to_i
            @search_size = (params[:per] || 25).to_i
            occurrences = User.find(@user[:id]).user_occurrence_occurrences

            @total = occurrences.length

            @results = WillPaginate::Collection.create(@page, @search_size, occurrences.length) do |pager|
              pager.replace occurrences[pager.offset, pager.per_page]
            end
            haml :profile
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
            user[:occurrences] = current_user.user_occurrence_downloadable
            user.to_json
          end

          app.get '/profile/download.csv' do
            protected!
            content_type "application/csv"
            attachment   "download.csv"
            user = User.find(@user[:id])
            records = user.user_occurrence_downloadable
            CSV.generate do |csv|
              csv << records.first.keys
              records.each { |r| csv << r.values }
            end
          end

          app.get '/candidates' do
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
                  parsed = Namae.parse other_name
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

            haml :candidates
          end

          app.get '/candidates/agent/:id' do
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

            haml :candidates_agent
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/orcid-refresh.json' do
            protected!
            content_type "application/json"
            data = get_orcid_profile(@user[:orcid])
            given = data[:person][:name][:"given-names"][:value]
            family = data[:person][:name][:"family-name"][:value]
            email = nil
            data[:person][:emails][:email].each do |mail|
              next if !mail[:primary]
              email = mail[:email]
            end
            other_names = data[:person][:"other-names"][:"other-name"].map{|n| n[:content]}.join("|") rescue nil
            country_code = data[:person][:addresses][:address][0][:country][:value] rescue nil
            country = IsoCountryCodes.find(country_code).name rescue nil
            user = User.find(@user[:id])
            user.update({
              family: family,
              given: given,
              email: email,
              other_names: other_names,
              country: country,
              updated: Time.now
            })
            update_session
            { message: "ok" }.to_json
          end

          app.get '/:orcid/specimens.json' do
            if params[:orcid].is_orcid?
              content_type "application/json"
              @viewed_user = User.find_by_orcid(params[:orcid])
              user = {}
              user[:personal] = @viewed_user
              user[:occurrences] = @viewed_user.user_occurrence_downloadable
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
              records = @viewed_user.user_occurrence_downloadable
              CSV.generate do |csv|
                csv << records.first.keys
                records.each { |r| csv << r.values }
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
                  identified: @viewed_user.identified_count,
                  recorded: @viewed_user.recorded_count
                }
                @families_identified = @viewed_user.identified_families
                @families_recorded = @viewed_user.recorded_families
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

          app.get '/:orcid/specimens' do
            if params[:orcid].is_orcid?
              @viewed_user = User.find_by_orcid(params[:orcid])
              if @viewed_user && @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                visible = @viewed_user.visible_user_occurrences
                @results = visible.paginate :page => params[:page]

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
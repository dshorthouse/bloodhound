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
            user = User.create_with(
                          family: family,
                          given: given,
                          orcid: session_data[:uid],
                          email: email,
                          other_names: other_names
                        )
                       .find_or_create_by(orcid: orcid)
            user_hash = user.as_json.symbolize_keys
            user_hash[:label] = user.label
            session[:omniauth] = user_hash
            redirect '/'
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
            req = JSON.parse(request.body.read).symbolize_keys
            user = User.find(@user[:id])
            user.is_public = req[:is_public]
            user.save
            update_session
            { message: "ok"}.to_json
          end

          app.get '/profile/download.json' do
            protected!
            current_user = User.find(@user[:id])
            user = {}
            user[:personal] = current_user
            user[:occurrences] = current_user.user_occurrence_occurrences
            user.to_json
          end

          app.get '/profile/download.csv' do
            protected!
            content_type "application/csv"
            attachment   "download.csv"
            user = User.find(@user[:id])
            records = user.user_occurrence_occurrences
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
                  name = ::Bloodhound::AgentUtility.clean(parsed[0])
                  family = !name[:family].nil? ? name[:family] : nil
                  given = !name[:given].nil? ? name[:given] : nil
                  if !family.nil?
                    agents.concat search_agents(family, given)
                  end
                end
              end

              uniq_agents = agents.compact.uniq

              if !uniq_agents.empty?
                scores = {}
                uniq_agents.each{|a| scores[a[:id]] = a[:score] }
                user = User.find(@user[:id])
                linked_ids = user.user_occurrences.pluck(:occurrence_id)
                recorded = OccurrenceRecorder.where(agent_id: scores.keys)
                                             .where.not(occurrence_id: linked_ids)
                                             .pluck(:agent_id, :occurrence_id)
                determined = OccurrenceDeterminer.where(agent_id: scores.keys)
                                                 .where.not(occurrence_id: linked_ids)
                                                 .pluck(:agent_id, :occurrence_id)
                occurrence_ids = (determined + recorded).uniq
                                                        .sort_by{|o| scores.fetch(o[0])}
                                                        .reverse
                                                        .map(&:last)
              end

              @total = occurrence_ids.length

              @results = WillPaginate::Collection.create(@page, @search_size, occurrence_ids.length) do |pager|
                pager.replace Occurrence.find(occurrence_ids[pager.offset, pager.per_page])
              end
            end

            haml :candidates
          end

          app.get '/candidates/agent/:id' do
            protected!
            occurrence_ids = []
            @page = (params[:page] || 1).to_i
            @search_size = (params[:per] || 25).to_i

            @searched_user = Agent.find(params[:id])
            user = User.find(@user[:id])
            linked_ids = user.user_occurrences.pluck(:occurrence_id)

            recorded = OccurrenceRecorder.where(agent_id: @searched_user.id)
                                         .where.not(occurrence_id: linked_ids)
                                         .pluck(:occurrence_id)
            determined = OccurrenceDeterminer.where(agent_id: @searched_user.id)
                                             .where.not(occurrence_id: linked_ids)
                                             .pluck(:occurrence_id)
            occurrence_ids = (recorded + determined).uniq

            @total = occurrence_ids.length

            @results = WillPaginate::Collection.create(@page, @search_size, occurrence_ids.length) do |pager|
              pager.replace Occurrence.find(occurrence_ids[pager.offset, pager.per_page])
            end
            haml :candidates_agent
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/orcid-refresh.json' do
            protected!
            data = get_orcid_profile(@user[:orcid])
            given = data[:person][:name][:"given-names"][:value]
            family = data[:person][:name][:"family-name"][:value]
            email = nil
            data[:person][:emails][:email].each do |mail|
              next if !mail[:primary]
              email = mail[:email]
            end
            other_names = data[:person][:"other-names"][:"other-name"].map{|n| n[:content]}.join("|") rescue nil
            user = User.find(@user[:id])
            user.update({
              family: family,
              given: given,
              email: email,
              other_names: other_names,
              updated: Time.now
            })
            update_session
            { message: "ok" }.to_json
          end

          app.get '/:orcid.json' do
            if params[:orcid].is_orcid?
              content_type "application/json"
              @viewed_user = User.find_by_orcid(params[:orcid])
              user = {}
              user[:personal] = @viewed_user
              user[:occurrences] = @viewed_user.user_occurrence_occurrences
              user.to_json
            else
              status 404
              haml :oops
            end
          end

          app.get '/:orcid.csv' do
            if params[:orcid].is_orcid?
              content_type "application/csv"
              attachment   "#{params[:orcid]}.csv"
              @viewed_user = User.find_by_orcid(params[:orcid])
              records = @viewed_user.user_occurrence_occurrences
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
                page = (params[:page] || 1).to_i
                visible = @viewed_user.user_occurrences.where(visible: true)
                @results = visible.paginate :page => params[:page]
                @total = {
                  identified: @viewed_user.identified_count,
                  recorded: @viewed_user.recorded_count
                }

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

        end

      end
    end
  end
end